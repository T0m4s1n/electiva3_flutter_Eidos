import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ChatDatabase {
  static const String _dbName = 'chat_app.db';
  static const int _dbVersion = 1;

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

  static Future<Database> get instance async {
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
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Manejo de migraciones futuras
      },
    );
  }

  // ======= CRUD mínimos =======

  static Future<void> upsertConversation(Map<String, Object?> conv) async {
    final Database db = await instance;
    await db.insert(
      'conversations',
      conv,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> upsertMessage(Map<String, Object?> msg) async {
    final Database db = await instance;
    await db.insert(
      'messages',
      msg,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, Object?>>> getPendingMessages() async {
    final Database db = await instance;
    return db.query('messages', where: 'status = ?', whereArgs: ['pending']);
  }

  static Future<List<Map<String, Object?>>> getConversationsByUser(
    String? userId,
  ) async {
    final Database db = await instance;
    if (userId == null) {
      return db.query('conversations', where: 'user_id IS NULL');
    }
    return db.query('conversations', where: 'user_id = ?', whereArgs: [userId]);
  }

  static Future<void> markMessagesSynced(List<String> ids) async {
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
    final Database db = await instance;
    return db.query(
      'messages',
      where: 'conversation_id = ? AND is_deleted = 0',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC, seq ASC',
    );
  }

  static Future<Map<String, Object?>?> getConversationById(
    String conversationId,
  ) async {
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
    final Database db = await instance;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
