import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../services/chat_database.dart';

class SyncService {
  final SupabaseClient supabase;

  SyncService(this.supabase);

  /// 1) Al iniciar sesión:
  /// - Promueve TODO lo local anónimo (user_id NULL) a la cuenta (userId).
  /// - Sube (push) a nube por upsert.
  /// - Hace un pull para dejar local = nube.
  Future<void> onLogin(String userId) async {
    await _promoteLocalAnonToUser(userId);
    await pushAll(userId);
    await pullAll(userId);
  }

  /// 2) Al hacer logout:
  /// - Borra absolutamente TODO lo local (conversaciones y mensajes).
  Future<void> onLogout() async {
    await ChatDatabase.purgeAllLocal();
  }

  /// Promueve datos locales anónimos (user_id NULL) a una cuenta concreta.
  Future<void> _promoteLocalAnonToUser(String userId) async {
    final Database db = await ChatDatabase.instance;

    // Conversaciones sin user_id: asignar userId y marcar timestamps
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

    // Mensajes de esas conversaciones: marcar status 'pending' para asegurar push
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

  /// Sube TODO de un usuario: conversaciones + mensajes (pending/ok) — idempotente por upsert.
  Future<void> pushAll(String userId) async {
    final Database db = await ChatDatabase.instance;

    // Conversaciones del usuario
    final List<Map<String, Object?>> convs = await db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (convs.isNotEmpty) {
      // Mapea a payload para Supabase
      final List<Map<String, dynamic>> payload = convs
          .map(
            (Map<String, Object?> c) => {
              'id': c['id'],
              'user_id': c['user_id'],
              'title': c['title'],
              'model': c['model'],
              'summary': c['summary'],
              'is_archived': (c['is_archived'] as int? ?? 0) == 1,
              'last_message_at': c['last_message_at'],
              'created_at': c['created_at'],
              'updated_at': c['updated_at'],
            },
          )
          .toList();

      await supabase.from('conversations').upsert(payload, onConflict: 'id');
    }

    // Mensajes del usuario (de las conversaciones anteriores)
    if (convs.isNotEmpty) {
      final List<String> convIds = convs
          .map((Map<String, Object?> c) => c['id'] as String)
          .toList();
      final String placeholders = List.filled(convIds.length, '?').join(',');
      final List<Map<String, Object?>> msgs = await db.rawQuery(
        'SELECT * FROM messages WHERE conversation_id IN ($placeholders)',
        convIds,
      );

      if (msgs.isNotEmpty) {
        // Subir en lotes para evitar payloads gigantes
        const int batchSize = 500;
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
        }

        // Marcar local como synced
        final List<String> ids = msgs
            .map((Map<String, Object?> m) => m['id'] as String)
            .toList();
        await ChatDatabase.markMessagesSynced(ids);
      }
    }
  }

  /// Baja TODO desde la nube para un usuario y reemplaza/merguea local (idempotente).
  Future<void> pullAll(String userId) async {
    final Database db = await ChatDatabase.instance;

    // 1) Conversations
    final List<Map<String, dynamic>> convs = await supabase
        .from('conversations')
        .select()
        .eq('user_id', userId);
    if (convs.isNotEmpty) {
      final Batch batch = db.batch();
      for (final Map<String, dynamic> c in convs) {
        batch.insert('conversations', {
          'id': c['id'],
          'user_id': c['user_id'],
          'title': c['title'],
          'model': c['model'],
          'summary': c['summary'],
          'is_archived': (c['is_archived'] == true) ? 1 : 0,
          'last_message_at': c['last_message_at'],
          'created_at': c['created_at'],
          'updated_at': c['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    // 2) Messages (por lotes si hay muchos)
    // Nota: Aquí hacemos un pull completo. Si prefieres incremental,
    // guarda un cursor (last_pulled_at) en una tabla meta local.

    // Pull simple (una sola llamada; si esperas muchos mensajes, pagina con range())
    final List<Map<String, dynamic>> msgs = await supabase
        .from('messages')
        .select()
        .inFilter(
          'conversation_id',
          convs.map((Map<String, dynamic> e) => e['id']).toList(),
        );
    if (msgs.isNotEmpty) {
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

  /// Sincronización incremental - solo datos pendientes
  Future<void> syncPending() async {
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Push datos pendientes
    await _pushPendingData(userId);

    // Pull datos nuevos desde la nube
    await _pullNewData(userId);
  }

  /// Push solo datos pendientes
  Future<void> _pushPendingData(String userId) async {
    final Database db = await ChatDatabase.instance;

    // Conversaciones pendientes
    final List<Map<String, Object?>> pendingConvs = await db.query(
      'conversations',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, _getLastSyncTime()],
    );

    if (pendingConvs.isNotEmpty) {
      final List<Map<String, dynamic>> payload = pendingConvs
          .map(
            (Map<String, Object?> c) => {
              'id': c['id'],
              'user_id': c['user_id'],
              'title': c['title'],
              'model': c['model'],
              'summary': c['summary'],
              'is_archived': (c['is_archived'] as int? ?? 0) == 1,
              'last_message_at': c['last_message_at'],
              'created_at': c['created_at'],
              'updated_at': c['updated_at'],
            },
          )
          .toList();

      await supabase.from('conversations').upsert(payload, onConflict: 'id');
    }

    // Mensajes pendientes
    final List<Map<String, Object?>> pendingMsgs = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
    );

    if (pendingMsgs.isNotEmpty) {
      const int batchSize = 100;
      for (int i = 0; i < pendingMsgs.length; i += batchSize) {
        final List<Map<String, Object?>> slice = pendingMsgs.sublist(
          i,
          (i + batchSize).clamp(0, pendingMsgs.length),
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

      // Marcar como sincronizados
      final List<String> ids = pendingMsgs
          .map((Map<String, Object?> m) => m['id'] as String)
          .toList();
      await ChatDatabase.markMessagesSynced(ids);
    }
  }

  /// Pull solo datos nuevos desde la nube
  Future<void> _pullNewData(String userId) async {
    final String lastSync = _getLastSyncTime();

    // Pull conversaciones actualizadas
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
          'is_archived': (c['is_archived'] == true) ? 1 : 0,
          'last_message_at': c['last_message_at'],
          'created_at': c['created_at'],
          'updated_at': c['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);
    }

    // Pull mensajes nuevos
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

    // Actualizar timestamp de última sincronización
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

  String _getLastSyncTime() {
    // Implementar almacenamiento del último timestamp de sync
    // Por ahora, usar un timestamp muy antiguo para sincronizar todo
    return DateTime(2020, 1, 1).toUtc().toIso8601String();
  }

  void _updateLastSyncTime() {
    // Implementar almacenamiento del último timestamp de sync
    // Por ahora, no hacer nada
  }
}
