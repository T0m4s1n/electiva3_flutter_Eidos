import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class ChatDatabase {
  // Local storage enabled for chat functionality - FORCE LOCAL MODE
  static const bool _enabled = true;
  
  static const String _dbName = 'chat_app.db';
  static const int _dbVersion = 3;

  static Database? _db;

  // ======= SQL NUBE (documentación) =======
  // Mantengo aquí los CREATE de nube como referencia 1:1 (no se ejecutan en local).
  // Ver sección de Supabase en este mismo archivo/documento.

  // ======= SQL LOCAL (SQLite) =======
  static const String _sqlPragmaFK = 'PRAGMA foreign_keys = ON;';

  static const String _sqlCreateConversations = '''
  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    title TEXT,
    model TEXT,
    summary TEXT,
    is_archived INTEGER NOT NULL DEFAULT 0,
    last_message_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  ''';

  static const String _sqlCreateMessages = '''
  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user','assistant','system','tool')),
    content TEXT NOT NULL,
    created_at TEXT NOT NULL,
    seq INTEGER NOT NULL,
    parent_id TEXT,
    status TEXT NOT NULL DEFAULT 'ok' CHECK (status IN ('ok','pending','error')),
    is_deleted INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
  );
  ''';

  static const String _sqlIdxConvUserUpdated = '''
  CREATE INDEX IF NOT EXISTS idx_conversations_user_updated
    ON conversations(user_id, updated_at);
  ''';

  static const String _sqlIdxMsgConvCreated = '''
  CREATE INDEX IF NOT EXISTS idx_messages_conv_created
ON messages(conversation_id, created_at, seq);
  ''';

  static const String _sqlCreateDocuments = '''
  CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    user_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    file_path TEXT,
    file_url TEXT,
    is_current_version INTEGER NOT NULL DEFAULT 1,
    version_number INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
  );
  ''';

  static const String _sqlIdxDocumentsConv = '''
  CREATE INDEX IF NOT EXISTS idx_documents_conv
    ON documents(conversation_id, updated_at);
  ''';

  static Future<Database> get instance async {
    if (!_enabled) {
      throw Exception('Local database is currently disabled.');
    }
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(dir.path, _dbName);
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (Database db) async {
        await db.execute(_sqlPragmaFK);
      },
      onCreate: (Database db, int version) async {
        await db.execute(_sqlCreateConversations);
        await db.execute(_sqlCreateMessages);
        await db.execute(_sqlIdxConvUserUpdated);
        await db.execute(_sqlIdxMsgConvCreated);
        await db.execute(_sqlCreateDocuments);
        await db.execute(_sqlIdxDocumentsConv);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        debugPrint('Database upgrade from version $oldVersion to $newVersion');
        
        if (oldVersion < 2) {
          debugPrint('Running migration to v2: Cleaning up orphaned messages');
          // Delete orphaned messages that don't have a valid conversation
          final int deletedCount = await db.delete(
            'messages',
            where: 'conversation_id NOT IN (SELECT id FROM conversations)',
          );
          debugPrint('Deleted $deletedCount orphaned messages');
        }
        
        if (oldVersion < 3) {
          debugPrint('Running migration to v3: Creating documents table');
          await db.execute(_sqlCreateDocuments);
          await db.execute(_sqlIdxDocumentsConv);
          debugPrint('Created documents table');
        }
      },
    );
  }

  // ======= CRUD mínimos =======

  static Future<void> upsertConversation(Map<String, Object?> conv) async {
    if (!_enabled) return; // Disabled
    final Database db = await instance;

    // Verificar si la conversación existe
    final String? id = conv['id'] as String?;
    if (id != null) {
      final List<Map<String, Object?>> existing = await db.query(
        'conversations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Si existe, hacer UPDATE solo de los campos proporcionados
        final Map<String, Object?> updateData = Map.from(conv);
        updateData.remove('id'); // No actualizar el ID

        if (updateData.isNotEmpty) {
          await db.update(
            'conversations',
            updateData,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        debugPrint('ChatDatabase: Updated conversation: $id');
      } else {
        // Si no existe, hacer INSERT completo usando transacción para asegurar commit
        await db.transaction((txn) async {
          await txn.insert('conversations', conv);
        });
        debugPrint('ChatDatabase: Created new conversation: $id');
        
        // Wait a moment for the transaction to commit
        await Future.delayed(const Duration(milliseconds: 50));
        
        // Verify the conversation was created
        final List<Map<String, Object?>> verify = await db.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        debugPrint('ChatDatabase: Verified conversation creation - found ${verify.length} entries');
        
        if (verify.isEmpty) {
          debugPrint('ChatDatabase: ERROR - Conversation was not persisted after insert!');
        }
      }
    } else {
      // Si no hay ID, hacer INSERT normal
      await db.insert('conversations', conv);
      debugPrint('ChatDatabase: Created conversation without ID');
    }
  }

  static Future<void> upsertMessage(Map<String, Object?> msg) async {
    if (!_enabled) {
      debugPrint('ChatDatabase: Database disabled, skipping upsertMessage');
      return;
    }
    
    try {
      final Database db = await instance;
      debugPrint('ChatDatabase: Attempting to save message: ${msg['id']}');
      debugPrint('ChatDatabase: Message data: $msg');
      
      // Ensure the conversation exists before inserting the message
      final String? conversationId = msg['conversation_id'] as String?;
      if (conversationId != null) {
        final List<Map<String, Object?>> existingConv = await db.query(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
          limit: 1,
        );
        
        if (existingConv.isEmpty) {
          debugPrint('ChatDatabase: ERROR - Conversation $conversationId does not exist in database');
          debugPrint('ChatDatabase: This will cause a foreign key constraint failure');
          debugPrint('ChatDatabase: Attempting to create a minimal conversation record...');
          
          // Use transaction to ensure both conversation and message are saved atomically
          await db.transaction((txn) async {
            // Create a minimal conversation record to fix the foreign key constraint
            await txn.insert('conversations', {
              'id': conversationId,
              'user_id': null,
              'title': 'New Chat',
              'model': 'gpt-4o-mini',
              'summary': null,
              'is_archived': 0,
              'last_message_at': msg['created_at'],
              'created_at': msg['created_at'],
              'updated_at': msg['created_at'],
            });
            
            // Now insert the message in the same transaction
            await txn.insert(
              'messages',
              msg,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          });
          
          debugPrint('ChatDatabase: Created conversation and message in single transaction');
        } else {
          debugPrint('ChatDatabase: Verified conversation exists');
          
          // Use transaction to ensure message is committed
          await db.transaction((txn) async {
            await txn.insert(
              'messages',
              msg,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          });
        }
      } else {
        // No conversation ID provided
        await db.insert(
          'messages',
          msg,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      // Wait a moment for transaction to commit
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify the message was saved
      final List<Map<String, Object?>> saved = await db.query(
        'messages',
        where: 'id = ?',
        whereArgs: [msg['id']],
        limit: 1,
      );
      
      debugPrint('ChatDatabase: Message saved successfully: ${msg['id']}');
      debugPrint('ChatDatabase: Verification - Found ${saved.length} message(s) with this ID');
      
      if (saved.isEmpty) {
        debugPrint('ChatDatabase: WARNING - Message was not found after insert!');
      }
    } catch (e) {
      debugPrint('ChatDatabase: Error upserting message: $e');
      debugPrint('ChatDatabase: Message data: $msg');
      rethrow;
    }
  }

  static Future<List<Map<String, Object?>>> getPendingMessages() async {
    if (!_enabled) return [];
    final Database db = await instance;
    return db.query('messages', where: 'status = ?', whereArgs: ['pending']);
  }

  static Future<List<Map<String, Object?>>> getConversationsByUser(
    String? userId,
  ) async {
    if (!_enabled) return [];
    final Database db = await instance;
    if (userId == null) {
      return db.query(
        'conversations',
        where: 'user_id IS NULL',
        orderBy: 'updated_at DESC, created_at DESC',
      );
    }
    return db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC, created_at DESC',
    );
  }

  static Future<void> markMessagesSynced(List<String> ids) async {
    if (!_enabled) return;
    if (ids.isEmpty) return;
    final Database db = await instance;
    final Batch batch = db.batch();
    for (final String id in ids) {
      batch.update(
        'messages',
        {'status': 'ok'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ======= Logout estricto (BORRAR todo lo local) =======
  static Future<void> purgeAllLocal() async {
    if (!_enabled) return; // Already disabled
    final Database db = await instance;
    final Batch batch = db.batch();
    batch.delete('messages');
    batch.delete('conversations');
    await batch.commit(noResult: true);
  }

  // ======= Métodos adicionales útiles =======

  static Future<List<Map<String, Object?>>> getMessagesByConversation(
    String conversationId,
  ) async {
    if (!_enabled) {
      debugPrint('ChatDatabase: Database disabled, returning empty message list');
      return [];
    }
    
    try {
      final Database db = await instance;
      
      // First, verify the conversation exists
      final List<Map<String, Object?>> convCheck = await db.query(
        'conversations',
        where: 'id = ?',
        whereArgs: [conversationId],
        limit: 1,
      );
      debugPrint('ChatDatabase: Verification - Found ${convCheck.length} conversation(s) with ID $conversationId');
      
      // Get all messages for this conversation (including deleted ones for debugging)
      final List<Map<String, Object?>> allMessages = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC, seq ASC',
      );
      debugPrint('ChatDatabase: Found ${allMessages.length} total messages (including deleted)');
      
      // Get only non-deleted messages
      final List<Map<String, Object?>> results = await db.query(
        'messages',
        where: 'conversation_id = ? AND is_deleted = 0',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC, seq ASC',
      );
      
      debugPrint('ChatDatabase: Retrieved ${results.length} active messages for conversation $conversationId');
      
      // Debug each message
      for (final Map<String, Object?> msg in results) {
        debugPrint('Message: id=${msg['id']}, role=${msg['role']}, content length=${(msg['content'] as String?)?.length ?? 0}');
      }
      
      return results;
    } catch (e) {
      debugPrint('ChatDatabase: Error retrieving messages: $e');
      return [];
    }
  }

  static Future<Map<String, Object?>?> getConversationById(
    String conversationId,
  ) async {
    if (!_enabled) return null;
    final Database db = await instance;
    final List<Map<String, Object?>> results = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<int> getNextSequenceNumber(String conversationId) async {
    if (!_enabled) return 1; // Return default sequence
    final Database db = await instance;
    final List<Map<String, Object?>> results = await db.rawQuery(
      'SELECT MAX(seq) as max_seq FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    final int maxSeq = results.first['max_seq'] as int? ?? 0;
    return maxSeq + 1;
  }

  static Future<void> updateConversationSummary(
    String conversationId,
    String summary,
  ) async {
    if (!_enabled) return;
    final Database db = await instance;
    await db.update(
      'conversations',
      {
        'summary': summary,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  static Future<void> markMessageAsDeleted(String messageId) async {
    if (!_enabled) return;
    final Database db = await instance;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  static Future<void> deleteSystemErrorMessages(String conversationId) async {
    if (!_enabled) return;
    final Database db = await instance;
    await db.delete(
      'messages',
      where: 'conversation_id = ? AND role = ? AND content LIKE ?',
      whereArgs: [conversationId, 'system', '%Sorry, I encountered an error%'],
    );
  }

  /// Delete a conversation and all its messages
  static Future<void> deleteConversation(String conversationId) async {
    if (!_enabled) return;
    final Database db = await instance;
    
    try {
      // Use a transaction to ensure atomicity
      await db.transaction((txn) async {
        // Delete all messages for this conversation first
        final int messagesDeleted = await txn.delete(
          'messages',
          where: 'conversation_id = ?',
          whereArgs: [conversationId],
        );
        debugPrint('Deleted $messagesDeleted messages for conversation $conversationId');
        
        // Delete the conversation
        final int conversationsDeleted = await txn.delete(
          'conversations',
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        debugPrint('Deleted $conversationsDeleted conversations with id $conversationId');
        
        if (conversationsDeleted == 0) {
          throw Exception('Conversation not found or already deleted');
        }
      });
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Clean up orphaned messages (messages without a valid conversation)
  /// This fixes foreign key constraint errors
  static Future<int> cleanupOrphanedMessages() async {
    if (!_enabled) return 0;
    final Database db = await instance;
    
    debugPrint('Cleaning up orphaned messages...');
    final int deletedCount = await db.delete(
      'messages',
      where: 'conversation_id NOT IN (SELECT id FROM conversations)',
    );
    debugPrint('Deleted $deletedCount orphaned messages');
    
    return deletedCount;
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
