import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../services/chat_database.dart';

class SyncService {
  final SupabaseClient supabase;

  SyncService(this.supabase);

  Future<void> onLogin(String userId) async {
    debugPrint(
      '🔄 SyncService.onLogin - Starting login sync for user: $userId',
    );

    try {
      debugPrint('🔄 Step 1: Promoting local anonymous data to user');
      await _promoteLocalAnonToUser(userId);

      debugPrint('🔄 Step 2: Pushing all local data to cloud');
      await pushAll(userId);

      debugPrint('🔄 Step 3: Pulling all cloud data to local');
      await pullAll(userId);

      debugPrint('✅ SyncService.onLogin - Login sync completed successfully');
    } catch (e) {
      debugPrint('❌ SyncService.onLogin - Error during login sync: $e');
      rethrow;
    }
  }

  Future<void> onLogout() async {
    debugPrint('🗑️ SyncService.onLogout - Starting logout cleanup');
    try {
      await ChatDatabase.purgeAllLocal();
      debugPrint('✅ SyncService.onLogout - Local data purged successfully');
    } catch (e) {
      debugPrint('❌ SyncService.onLogout - Error purging local data: $e');
      rethrow;
    }
  }

  Future<void> _promoteLocalAnonToUser(String userId) async {
    final Database db = await ChatDatabase.instance;

    final List<Map<String, Object?>> convsAnon = await db.query(
      'conversations',
      where: 'user_id IS NULL',
    );
    if (convsAnon.isEmpty) return;

    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final Batch batch = db.batch();
    for (final Map<String, Object?> c in convsAnon) {
      final Map<String, Object?> updated = Map<String, Object?>.from(c);
      updated['user_id'] = userId;
      updated['updated_at'] = nowIso;
      batch.insert(
        'conversations',
        updated,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    final List<String> convIds = convsAnon
        .map((Map<String, Object?> c) => c['id'] as String)
        .toList();
    final Batch msgBatch = db.batch();
    for (final String convId in convIds) {
      msgBatch.rawUpdate(
        "UPDATE messages SET status = 'pending' WHERE conversation_id = ?",
        [convId],
      );
    }
    await msgBatch.commit(noResult: true);
  }

  Future<void> pushAll(String userId) async {
    debugPrint(
      '📤 SyncService.pushAll - Starting push to cloud for user: $userId',
    );
    final Database db = await ChatDatabase.instance;

    // Conversaciones del usuario
    final List<Map<String, Object?>> convs = await db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    debugPrint('📤 Found ${convs.length} conversations to push');

    if (convs.isNotEmpty) {
      // Process conversations in batches to avoid blocking UI
      const int batchSize = 50;
      for (int i = 0; i < convs.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, convs.length);
      final List<Map<String, dynamic>> payload = convs
            .sublist(i, end)
          .map(
            (Map<String, Object?> c) => {
              'id': c['id'],
              'user_id': c['user_id'],
              'title': c['title'],
              'model': c['model'],
              'summary': c['summary'],
              'context': c['context'],
              'is_archived': (c['is_archived'] as int? ?? 0) == 1,
              'last_message_at': c['last_message_at'],
              'created_at': c['created_at'],
              'updated_at': c['updated_at'],
            },
          )
          .toList();

      await supabase.from('conversations').upsert(payload, onConflict: 'id');
        // Yield to UI thread between batches
        await Future.delayed(const Duration(milliseconds: 10));
      }
      debugPrint('✅ Pushed ${convs.length} conversations to cloud');
    }

    if (convs.isNotEmpty) {
      final List<String> convIds = convs
          .map((Map<String, Object?> c) => c['id'] as String)
          .toList();
      final String placeholders = List.filled(convIds.length, '?').join(',');
      final List<Map<String, Object?>> msgs = await db.rawQuery(
        'SELECT * FROM messages WHERE conversation_id IN ($placeholders)',
        convIds,
      );

      debugPrint('📤 Found ${msgs.length} messages to push');

      if (msgs.isNotEmpty) {
        const int batchSize = 100;
        int totalPushed = 0;
        for (int i = 0; i < msgs.length; i += batchSize) {
          final List<Map<String, Object?>> slice = msgs.sublist(
            i,
            (i + batchSize).clamp(0, msgs.length),
          );
          final List<Map<String, dynamic>> payload = slice
              .map(
                (Map<String, Object?> m) => {
                  'id': m['id'],
                  'conversation_id': m['conversation_id'],
                  'role': m['role'],
                  'content': _tryParseJson(m['content']),
                  'created_at': m['created_at'],
                  'seq': m['seq'],
                  'parent_id': m['parent_id'],
                  'status': m['status'],
                  'is_deleted': (m['is_deleted'] as int? ?? 0) == 1,
                },
              )
              .toList();

          await supabase.from('messages').upsert(payload, onConflict: 'id');
          totalPushed += slice.length;
          debugPrint(
            '📤 Pushed batch ${(i ~/ batchSize) + 1}: ${slice.length} messages',
          );
          // Yield to UI thread between batches
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Mark messages as synced in batches
        const int syncBatchSize = 100;
        for (int i = 0; i < msgs.length; i += syncBatchSize) {
          final end = (i + syncBatchSize).clamp(0, msgs.length);
        final List<String> ids = msgs
              .sublist(i, end)
            .map((Map<String, Object?> m) => m['id'] as String)
            .toList();
        await ChatDatabase.markMessagesSynced(ids);
          // Yield to UI thread between batches
          await Future.delayed(const Duration(milliseconds: 10));
        }
        debugPrint(
          '✅ Pushed $totalPushed messages to cloud and marked as synced',
        );
      }
    }

    debugPrint('✅ SyncService.pushAll - Push to cloud completed successfully');
  }

  Future<void> pullAll(String userId) async {
    debugPrint(
      '📥 SyncService.pullAll - Starting pull from cloud for user: $userId',
    );
    final Database db = await ChatDatabase.instance;

    // 1) Conversations - batch in smaller chunks to avoid blocking
    final List<Map<String, dynamic>> convs = await supabase
        .from('conversations')
        .select()
        .eq('user_id', userId);
    if (convs.isNotEmpty) {
      // Process in batches to avoid blocking UI
      const int batchSize = 50;
      for (int i = 0; i < convs.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize).clamp(0, convs.length);
        for (int j = i; j < end; j++) {
          final c = convs[j];
        batch.insert('conversations', {
          'id': c['id'],
          'user_id': c['user_id'],
          'title': c['title'],
          'model': c['model'],
          'summary': c['summary'],
          'context': c['context'],
          'is_archived': (c['is_archived'] == true) ? 1 : 0,
          'last_message_at': c['last_message_at'],
          'created_at': c['created_at'],
          'updated_at': c['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
        // Yield to UI thread between batches
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // 2) Messages - only fetch if we have conversations
    if (convs.isNotEmpty) {
      final List<String> convIds = convs.map((Map<String, dynamic> e) => e['id'] as String).toList();
      
      // Fetch messages in batches to avoid large queries
      const int messageBatchSize = 100;
      for (int i = 0; i < convIds.length; i += messageBatchSize) {
        final end = (i + messageBatchSize).clamp(0, convIds.length);
        final batchIds = convIds.sublist(i, end);

    final List<Map<String, dynamic>> msgs = await supabase
        .from('messages')
        .select()
            .inFilter('conversation_id', batchIds);
            
    if (msgs.isNotEmpty) {
          // Process messages in smaller batches
          const int insertBatchSize = 50;
          for (int j = 0; j < msgs.length; j += insertBatchSize) {
            final batch = db.batch();
            final endMsg = (j + insertBatchSize).clamp(0, msgs.length);
            for (int k = j; k < endMsg; k++) {
              final m = msgs[k];
        batch.insert('messages', {
          'id': m['id'],
          'conversation_id': m['conversation_id'],
          'role': m['role'],
          'content': jsonEncode(m['content']),
          'created_at': m['created_at'],
          'seq': m['seq'],
          'parent_id': m['parent_id'],
          'status': m['status'] ?? 'ok',
          'is_deleted': (m['is_deleted'] == true) ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
            // Yield to UI thread between batches
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }
    }
  }

  Future<void> syncPending() async {
    debugPrint('🔄 SyncService.syncPending - Starting background sync');
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint(
        '⚠️ SyncService.syncPending - No user logged in, skipping sync',
      );
      return;
    }

    try {
      debugPrint('🔄 Step 1: Pushing pending data to cloud');
      await pushPendingData(userId);

      debugPrint('🔄 Step 2: Pulling new data from cloud');
      await _pullNewData(userId);

      debugPrint(
        '✅ SyncService.syncPending - Background sync completed successfully',
      );
    } catch (e) {
      debugPrint(
        '❌ SyncService.syncPending - Error during background sync: $e',
      );
    }
  }

  /// Manual full sync: push all local data and pull all cloud data
  Future<void> manualSync() async {
    debugPrint('🔄 SyncService.manualSync - Starting manual full sync');
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint(
        '⚠️ SyncService.manualSync - No user logged in, skipping sync',
      );
      throw Exception('User not logged in');
    }

    try {
      debugPrint('🔄 Step 1: Pushing all local data to cloud');
      await pushAll(userId);

      debugPrint('🔄 Step 2: Pulling all cloud data to local');
      await pullAll(userId);

      debugPrint(
        '✅ SyncService.manualSync - Manual sync completed successfully',
      );
    } catch (e) {
      debugPrint(
        '❌ SyncService.manualSync - Error during manual sync: $e',
      );
      rethrow;
    }
  }

  Future<void> pushPendingData(String userId) async {
    debugPrint('📤 SyncService.pushPendingData - Starting push');
    final Database db = await ChatDatabase.instance;

    // Get all conversations (not just pending ones)
    final List<Map<String, Object?>> allConvs = await db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    debugPrint('📤 Found ${allConvs.length} conversations to push');

    if (allConvs.isNotEmpty) {
      final List<Map<String, dynamic>> payload = allConvs
          .map(
            (Map<String, Object?> c) => {
              'id': c['id'],
              'user_id': c['user_id'],
              'title': c['title'],
              'model': c['model'],
              'summary': c['summary'],
              'context': c['context'],
              'is_archived': (c['is_archived'] as int? ?? 0) == 1,
              'last_message_at': c['last_message_at'],
              'created_at': c['created_at'],
              'updated_at': c['updated_at'],
            },
          )
          .toList();

      await supabase.from('conversations').upsert(payload, onConflict: 'id');
      debugPrint('📤 Pushed ${allConvs.length} conversations to Supabase');
    }

    // Get all messages for this user's conversations (not just pending)
    final List<String> convIds = allConvs
        .map((c) => c['id'] as String)
        .toList();
    if (convIds.isNotEmpty) {
      // Query for messages by conversation IDs
      final String placeholders = List.filled(convIds.length, '?').join(',');
      final List<Map<String, Object?>> allMsgs = await db.rawQuery(
        'SELECT * FROM messages WHERE conversation_id IN ($placeholders)',
        convIds,
      );
      debugPrint('📤 Found ${allMsgs.length} messages to push');

      if (allMsgs.isNotEmpty) {
        const int batchSize = 100;
        for (int i = 0; i < allMsgs.length; i += batchSize) {
          final List<Map<String, Object?>> slice = allMsgs.sublist(
            i,
            (i + batchSize).clamp(0, allMsgs.length),
          );
          final List<Map<String, dynamic>> payload = slice
              .map(
                (Map<String, Object?> m) => {
                  'id': m['id'],
                  'conversation_id': m['conversation_id'],
                  'role': m['role'],
                  'content': _tryParseJson(m['content']),
                  'created_at': m['created_at'],
                  'seq': m['seq'],
                  'parent_id': m['parent_id'],
                  'status': m['status'],
                  'is_deleted': (m['is_deleted'] as int? ?? 0) == 1,
                },
              )
              .toList();

          await supabase.from('messages').upsert(payload, onConflict: 'id');
        }
        debugPrint('📤 Pushed ${allMsgs.length} messages to Supabase');
      }
    }
    debugPrint('📤 SyncService.pushPendingData - Push complete');
  }

  Future<void> _pullNewData(String userId) async {
    final String lastSync = _getLastSyncTime();

    final List<Map<String, dynamic>> convs = await supabase
        .from('conversations')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastSync);
    if (convs.isNotEmpty) {
      final Database db = await ChatDatabase.instance;
      final Batch batch = db.batch();

      for (final Map<String, dynamic> c in convs) {
        batch.insert('conversations', {
          'id': c['id'],
          'user_id': c['user_id'],
          'title': c['title'],
          'model': c['model'],
          'summary': c['summary'],
          'context': c['context'],
          'is_archived': (c['is_archived'] == true) ? 1 : 0,
          'last_message_at': c['last_message_at'],
          'created_at': c['created_at'],
          'updated_at': c['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    }

    if (convs.isNotEmpty) {
      final List<String> convIds = convs
          .map((Map<String, dynamic> e) => e['id'] as String)
          .toList();
      final List<Map<String, dynamic>> msgs = await supabase
          .from('messages')
          .select()
          .inFilter('conversation_id', convIds)
          .gte('created_at', lastSync);
      if (msgs.isNotEmpty) {
        final Database db = await ChatDatabase.instance;
        final Batch batch = db.batch();

        for (final Map<String, dynamic> m in msgs) {
          batch.insert('messages', {
            'id': m['id'],
            'conversation_id': m['conversation_id'],
            'role': m['role'],
            'content': jsonEncode(m['content']),
            'created_at': m['created_at'],
            'seq': m['seq'],
            'parent_id': m['parent_id'],
            'status': m['status'] ?? 'ok',
            'is_deleted': (m['is_deleted'] == true) ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        await batch.commit(noResult: true);
      }
    }

    _updateLastSyncTime();
  }

  static Map<String, dynamic> _tryParseJson(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {'text': raw?.toString() ?? ''};
  }

  /// Delete a conversation from Supabase
  Future<void> deleteConversationFromCloud(String conversationId) async {
    try {
      debugPrint('🗑️ Deleting conversation $conversationId from Supabase');

      // First delete all messages from this conversation
      await supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      debugPrint(
        '✓ Deleted messages for conversation $conversationId from Supabase',
      );

      // Then delete the conversation itself
      await supabase.from('conversations').delete().eq('id', conversationId);

      debugPrint('✓ Deleted conversation $conversationId from Supabase');
    } catch (e) {
      debugPrint('❌ Error deleting conversation from Supabase: $e');
      rethrow;
    }
  }

  String _getLastSyncTime() {
    return DateTime(2020, 1, 1).toUtc().toIso8601String();
  }

  void _updateLastSyncTime() {}
}
