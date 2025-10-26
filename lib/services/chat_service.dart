import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../services/chat_database.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../models/chat_models.dart';

class ChatService {
  static final SyncService _syncService = AuthService.syncService;

  /// Crear una nueva conversación
  static Future<ConversationLocal> createConversation({
    String? title,
    String? model,
  }) async {
    final String? userId = AuthService.currentUser?.id;
    final ConversationLocal conversation = ConversationFactory.createNew(
      title: title,
      model: model,
      userId: userId,
    );

    await ChatDatabase.upsertConversation(conversation.toRow());

    // Si el usuario está logueado, sincronizar
    if (userId != null) {
      await _syncService.syncPending();
    }

    return conversation;
  }

  /// Agregar un mensaje a una conversación
  static Future<MessageLocal> addMessage({
    required String conversationId,
    required String role,
    required Map<String, dynamic> content,
    String? parentId,
    String status = 'ok',
  }) async {
    // Obtener el siguiente número de secuencia
    final int seq = await ChatDatabase.getNextSequenceNumber(conversationId);

    final MessageLocal message = MessageFactory.createNew(
      conversationId: conversationId,
      role: role,
      content: content,
      parentId: parentId,
      status: status,
    ).copyWith(seq: seq);

    await ChatDatabase.upsertMessage(message.toRow());

    // Actualizar last_message_at de la conversación
    final String now = DateTime.now().toUtc().toIso8601String();
    await _updateConversationTimestamp(conversationId, now);

    debugPrint('addMessage - Message saved locally: ${message.id}');
    debugPrint('addMessage - Current user: ${AuthService.currentUser?.id}');

    // Si el usuario está logueado, sincronizar en background (no bloquear)
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      // Sincronizar en background para no bloquear la respuesta
      _syncService.syncPending().catchError((e) {
        debugPrint('Background sync error: $e');
      });
    }

    return message;
  }

  /// Obtener todas las conversaciones del usuario actual
  static Future<List<ConversationLocal>> getConversations() async {
    final String? userId = AuthService.currentUser?.id;
    final List<Map<String, Object?>> rows =
        await ChatDatabase.getConversationsByUser(userId);

    return rows
        .map((Map<String, Object?> row) => ConversationLocal.fromRow(row))
        .toList();
  }

  /// Obtener mensajes de una conversación específica
  static Future<List<MessageLocal>> getMessages(String conversationId) async {
    final List<Map<String, Object?>> rows =
        await ChatDatabase.getMessagesByConversation(conversationId);

    return rows
        .map((Map<String, Object?> row) => MessageLocal.fromRow(row))
        .toList();
  }

  /// Obtener una conversación por ID
  static Future<ConversationLocal?> getConversation(
    String conversationId,
  ) async {
    final Map<String, Object?>? row = await ChatDatabase.getConversationById(
      conversationId,
    );

    if (row == null) return null;
    return ConversationLocal.fromRow(row);
  }

  /// Actualizar el título de una conversación
  static Future<void> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    final String now = DateTime.now().toUtc().toIso8601String();

    // Ahora upsertConversation maneja esto correctamente
    await ChatDatabase.upsertConversation({
      'id': conversationId,
      'title': title,
      'updated_at': now,
    });

    // Sincronizar si está logueado
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      await _syncService.syncPending();
    }
  }

  /// Actualizar el resumen de una conversación
  static Future<void> updateConversationSummary(
    String conversationId,
    String summary,
  ) async {
    await ChatDatabase.updateConversationSummary(conversationId, summary);

    // Sincronizar si está logueado
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      await _syncService.syncPending();
    }
  }

  /// Archivar/desarchivar una conversación
  static Future<void> toggleConversationArchive(
    String conversationId,
    bool isArchived,
  ) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await ChatDatabase.upsertConversation({
      'id': conversationId,
      'is_archived': isArchived ? 1 : 0,
      'updated_at': now,
    });

    // Sincronizar si está logueado
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      await _syncService.syncPending();
    }
  }

  /// Marcar un mensaje como eliminado (soft delete)
  static Future<void> deleteMessage(String messageId) async {
    await ChatDatabase.markMessageAsDeleted(messageId);

    // Sincronizar si está logueado
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      await _syncService.syncPending();
    }
  }

  /// Eliminar una conversación y todos sus mensajes
  static Future<void> deleteConversation(String conversationId) async {
    final Database db = await ChatDatabase.instance;
    final Batch batch = db.batch();

    // Eliminar mensajes primero (por las foreign keys)
    batch.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    // Eliminar conversación
    batch.delete('conversations', where: 'id = ?', whereArgs: [conversationId]);

    await batch.commit(noResult: true);

    // Sincronizar si está logueado
    final String? userId = AuthService.currentUser?.id;
    if (userId != null) {
      await _syncService.syncPending();
    }
  }

  /// Sincronizar datos pendientes manualmente
  static Future<void> syncPendingData() async {
    await AuthService.syncPendingData();
  }

  /// Obtener estadísticas de la base de datos local
  static Future<Map<String, int>> getLocalStats() async {
    final Database db = await ChatDatabase.instance;

    final List<Map<String, Object?>> convCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations',
    );
    final List<Map<String, Object?>> msgCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages',
    );
    final List<Map<String, Object?>> pendingCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE status = ?',
      ['pending'],
    );

    return {
      'conversations': convCount.first['count'] as int,
      'messages': msgCount.first['count'] as int,
      'pending_messages': pendingCount.first['count'] as int,
    };
  }

  /// Limpiar datos locales (útil para testing o reset)
  static Future<void> clearLocalData() async {
    await ChatDatabase.purgeAllLocal();
  }

  /// Crear un mensaje de usuario
  static Future<MessageLocal> createUserMessage({
    required String conversationId,
    required String text,
  }) async {
    debugPrint('createUserMessage - Conversation ID: $conversationId');
    debugPrint('createUserMessage - Text: $text');
    debugPrint(
      'createUserMessage - Current user: ${AuthService.currentUser?.id}',
    );

    final message = await addMessage(
      conversationId: conversationId,
      role: 'user',
      content: {'text': text},
      status: 'ok',
    );

    debugPrint('createUserMessage - Created message ID: ${message.id}');
    return message;
  }

  /// Crear un mensaje del asistente
  static Future<MessageLocal> createAssistantMessage({
    required String conversationId,
    required String text,
    String status = 'ok',
  }) async {
    return addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: {'text': text},
      status: status,
    );
  }

  /// Crear un mensaje del sistema
  static Future<MessageLocal> createSystemMessage({
    required String conversationId,
    required String text,
  }) async {
    return addMessage(
      conversationId: conversationId,
      role: 'system',
      content: {'text': text},
      status: 'ok',
    );
  }

  /// Crear un mensaje de herramienta (tool call)
  static Future<MessageLocal> createToolMessage({
    required String conversationId,
    required String toolName,
    required Map<String, dynamic> toolInput,
    String? toolOutput,
  }) async {
    return addMessage(
      conversationId: conversationId,
      role: 'tool',
      content: {
        'tool_name': toolName,
        'tool_input': toolInput,
        'tool_output': toolOutput,
      },
      status: 'ok',
    );
  }

  /// Obtener el contexto para IA (últimos N mensajes + resumen)
  static Future<Map<String, dynamic>> getContextForAI({
    required String conversationId,
    int maxMessages = 30,
  }) async {
    final ConversationLocal? conversation = await getConversation(
      conversationId,
    );
    if (conversation == null) {
      throw Exception('Conversation not found');
    }

    final List<MessageLocal> messages = await getMessages(conversationId);

    debugPrint('getContextForAI - Conversation ID: $conversationId');
    debugPrint('getContextForAI - Total messages found: ${messages.length}');
    debugPrint(
      'getContextForAI - Current user: ${AuthService.currentUser?.id}',
    );

    // Tomar solo los últimos N mensajes
    final List<MessageLocal> recentMessages = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;

    debugPrint('getContextForAI - Recent messages: ${recentMessages.length}');

    final List<Map<String, dynamic>> formattedMessages = recentMessages
        .map(
          (MessageLocal msg) => {
            'id': msg.id,
            'role': msg.role,
            'content': msg.content,
            'created_at': msg.createdAt,
            'seq': msg.seq,
          },
        )
        .toList();

    debugPrint('Context for AI - Messages count: ${formattedMessages.length}');
    for (int i = 0; i < formattedMessages.length; i++) {
      final msg = formattedMessages[i];
      debugPrint('Message $i: role=${msg['role']}, content=${msg['content']}');
    }

    return {
      'conversation': {
        'id': conversation.id,
        'title': conversation.title,
        'model': conversation.model,
        'summary': conversation.summary,
      },
      'messages': formattedMessages,
      'total_messages': messages.length,
    };
  }

  /// Actualizar timestamp de conversación de manera segura
  static Future<void> _updateConversationTimestamp(
    String conversationId,
    String timestamp,
  ) async {
    // Ahora upsertConversation maneja esto correctamente
    await ChatDatabase.upsertConversation({
      'id': conversationId,
      'last_message_at': timestamp,
      'updated_at': timestamp,
    });
  }

  /// Limpiar mensajes de error del sistema de una conversación
  static Future<void> clearSystemErrorMessages(String conversationId) async {
    try {
      await ChatDatabase.deleteSystemErrorMessages(conversationId);
    } catch (e) {
      debugPrint('Error clearing system error messages: $e');
    }
  }
}
