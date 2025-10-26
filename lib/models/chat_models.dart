import 'dart:convert';
import 'package:uuid/uuid.dart';

// ======= Helpers de mapeo =======

class ConversationLocal {
  final String id;
  final String? userId;
  final String? title;
  final String? model;
  final String? summary;
  final bool isArchived;
  final String? lastMessageAt; // ISO-8601
  final String createdAt; // ISO-8601
  final String updatedAt; // ISO-8601

  ConversationLocal({
    required this.id,
    this.userId,
    this.title,
    this.model,
    this.summary,
    required this.isArchived,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'model': model,
    'summary': summary,
    'is_archived': isArchived ? 1 : 0,
    'last_message_at': lastMessageAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory ConversationLocal.fromRow(Map<String, Object?> row) {
    return ConversationLocal(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      title: row['title'] as String?,
      model: row['model'] as String?,
      summary: row['summary'] as String?,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      lastMessageAt: row['last_message_at'] as String?,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }

  ConversationLocal copyWith({
    String? id,
    String? userId,
    String? title,
    String? model,
    String? summary,
    bool? isArchived,
    String? lastMessageAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return ConversationLocal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      model: model ?? this.model,
      summary: summary ?? this.summary,
      isArchived: isArchived ?? this.isArchived,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ConversationLocal(id: $id, userId: $userId, title: $title, model: $model, summary: $summary, isArchived: $isArchived, lastMessageAt: $lastMessageAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationLocal &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.model == model &&
        other.summary == summary &&
        other.isArchived == isArchived &&
        other.lastMessageAt == lastMessageAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      title,
      model,
      summary,
      isArchived,
      lastMessageAt,
      createdAt,
      updatedAt,
    );
  }
}

class MessageLocal {
  final String id;
  final String conversationId;
  final String role; // 'user' | 'assistant' | 'system' | 'tool'
  final Map<String, dynamic> content; // JSON
  final String createdAt; // ISO-8601
  final int seq;
  final String? parentId;
  final String status; // 'ok' | 'pending' | 'error'
  final bool isDeleted;

  MessageLocal({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.seq,
    this.parentId,
    this.status = 'ok',
    this.isDeleted = false,
  });

  Map<String, Object?> toRow() => {
    'id': id,
    'conversation_id': conversationId,
    'role': role,
    'content': jsonEncode(content),
    'created_at': createdAt,
    'seq': seq,
    'parent_id': parentId,
    'status': status,
    'is_deleted': isDeleted ? 1 : 0,
  };

  factory MessageLocal.fromRow(Map<String, Object?> row) {
    Map<String, dynamic> content;
    try {
      content = jsonDecode(row['content'] as String) as Map<String, dynamic>;
    } catch (e) {
      content = {'text': row['content']?.toString() ?? ''};
    }

    return MessageLocal(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      role: row['role'] as String,
      content: content,
      createdAt: row['created_at'] as String,
      seq: row['seq'] as int,
      parentId: row['parent_id'] as String?,
      status: row['status'] as String? ?? 'ok',
      isDeleted: (row['is_deleted'] as int? ?? 0) == 1,
    );
  }

  MessageLocal copyWith({
    String? id,
    String? conversationId,
    String? role,
    Map<String, dynamic>? content,
    String? createdAt,
    int? seq,
    String? parentId,
    String? status,
    bool? isDeleted,
  }) {
    return MessageLocal(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      seq: seq ?? this.seq,
      parentId: parentId ?? this.parentId,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'MessageLocal(id: $id, conversationId: $conversationId, role: $role, content: $content, createdAt: $createdAt, seq: $seq, parentId: $parentId, status: $status, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageLocal &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.role == role &&
        other.content.toString() == content.toString() &&
        other.createdAt == createdAt &&
        other.seq == seq &&
        other.parentId == parentId &&
        other.status == status &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      conversationId,
      role,
      content.toString(),
      createdAt,
      seq,
      parentId,
      status,
      isDeleted,
    );
  }
}

// ======= Utilidades para generación de IDs =======

class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String generateConversationId() {
    try {
      // Usar UUID v4 para IDs únicos
      return _uuid.v4();
    } catch (e) {
      // Fallback a método simple si hay error
      return _generateSimpleId();
    }
  }

  static String generateMessageId() {
    try {
      // Usar UUID v4 para IDs únicos
      return _uuid.v4();
    } catch (e) {
      // Fallback a método simple si hay error
      return _generateSimpleId();
    }
  }

  static String _generateSimpleId() {
    // Método simple de respaldo
    final DateTime now = DateTime.now();
    final String timestamp = now.millisecondsSinceEpoch.toString();
    final String random = now.microsecond.toString().padLeft(6, '0');
    return '${timestamp}_${random}';
  }
}

// ======= Factory methods para crear objetos =======

class ConversationFactory {
  static ConversationLocal createNew({
    String? id,
    String? title,
    String? model,
    String? userId,
  }) {
    final String now = DateTime.now().toUtc().toIso8601String();
    return ConversationLocal(
      id: id ?? IdGenerator.generateConversationId(),
      userId: userId,
      title: title ?? 'Nueva conversación',
      model: model ?? 'gpt-4o-mini',
      summary: null,
      isArchived: false,
      lastMessageAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class MessageFactory {
  static MessageLocal createNew({
    required String conversationId,
    required String role,
    required Map<String, dynamic> content,
    String? parentId,
    String status = 'ok',
  }) {
    final String now = DateTime.now().toUtc().toIso8601String();
    return MessageLocal(
      id: IdGenerator.generateMessageId(),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: now,
      seq: 0, // Se actualizará al guardar
      parentId: parentId,
      status: status,
      isDeleted: false,
    );
  }
}
