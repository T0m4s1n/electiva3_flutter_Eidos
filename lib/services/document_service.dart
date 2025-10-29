import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'chat_database.dart';
import 'auth_service.dart';
import '../models/chat_models.dart';

class DocumentService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'documents';

  /// Save a document with versioning
  static Future<String> saveDocument({
    required String conversationId,
    required String title,
    required String content,
    String? documentId,
  }) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      
      // Save locally first regardless of user authentication
      final String savedDocId = await _saveDocumentLocally(
        conversationId: conversationId,
        title: title,
        content: content,
        documentId: documentId,
      );
      
      if (userId == null) {
        debugPrint('DocumentService: No user ID, saved locally only');
        return savedDocId;
      }

      // If we have a documentId, this is an update - create a new version
      if (documentId != null) {
        await _createNewVersion(
          documentId: documentId,
          content: content,
          userId: userId,
        );
      } else {
        // Create a new document in Supabase
        await _createNewDocument(
          conversationId: conversationId,
          title: title,
          content: content,
          userId: userId,
          documentId: savedDocId,
        );
      }

      debugPrint('DocumentService: Document saved successfully with ID: $savedDocId');
      return savedDocId;
    } catch (e) {
      debugPrint('DocumentService: Error saving document - $e');
      // Return the document ID from local storage even if Supabase fails
      return await _saveDocumentLocally(
        conversationId: conversationId,
        title: title,
        content: content,
        documentId: documentId,
      );
    }
  }

  /// Create a new document in Supabase
  static Future<void> _createNewDocument({
    required String conversationId,
    required String title,
    required String content,
    required String userId,
    required String documentId,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();

    // Save to database
    await _supabase.from('documents').insert({
      'id': documentId,
      'conversation_id': conversationId,
      'user_id': userId,
      'title': title,
      'content': content,
      'is_current_version': true,
      'version_number': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Save to storage
    await _uploadToStorage(
      userId: userId,
      documentId: documentId,
      content: content,
      version: 1,
    );
  }

  /// Create a new version of an existing document
  static Future<void> _createNewVersion({
    required String documentId,
    required String content,
    required String userId,
  }) async {
    // Get current version
    final currentDoc = await _supabase
        .from('documents')
        .select()
        .eq('id', documentId)
        .single();

    final int newVersion = (currentDoc['version_number'] as int) + 1;
    final String now = DateTime.now().toUtc().toIso8601String();

    // Mark old version as not current
    await _supabase
        .from('documents')
        .update({'is_current_version': false})
        .eq('id', documentId);

    // Create new version in document_versions table
    await _supabase.from('document_versions').insert({
      'id': IdGenerator.generateConversationId(),
      'document_id': documentId,
      'user_id': userId,
      'content': content,
      'version_number': newVersion - 1,
      'created_at': now,
      'created_by': userId,
    });

    // Update current document
    await _supabase.from('documents').update({
      'content': content,
      'version_number': newVersion,
      'updated_at': now,
    }).eq('id', documentId);

    // Upload new version to storage
    await _uploadToStorage(
      userId: userId,
      documentId: documentId,
      content: content,
      version: newVersion,
    );

    debugPrint('DocumentService: Created version $newVersion');
  }

  /// Upload document content to Supabase Storage
  static Future<void> _uploadToStorage({
    required String userId,
    required String documentId,
    required String content,
    required int version,
  }) async {
    try {
      final String path = '$userId/$documentId/v$version.json';
      final String jsonContent = jsonEncode({'content': content});

      await _supabase.storage.from(_bucketName).uploadBinary(
        path,
        utf8.encode(jsonContent),
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      debugPrint('DocumentService: Uploaded to storage at $path');
    } catch (e) {
      debugPrint('DocumentService: Failed to upload to storage - $e');
      // Don't fail the whole operation if storage fails
    }
  }

  /// Save document locally (SQLite)
  static Future<String> _saveDocumentLocally({
    required String conversationId,
    required String title,
    required String content,
    String? documentId,
  }) async {
    final String docId = documentId ?? IdGenerator.generateConversationId();
    final String now = DateTime.now().toUtc().toIso8601String();
    final String? userId = AuthService.currentUser?.id;

    final Database db = await ChatDatabase.instance;
    await db.insert(
      'documents',
      {
        'id': docId,
        'conversation_id': conversationId,
        'user_id': userId,
        'title': title,
        'content': content,
        'is_current_version': 1,
        'version_number': 1,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('DocumentService: Saved locally to SQLite with ID: $docId');
    return docId;
  }

  /// Get a document by ID
  static Future<Map<String, dynamic>?> getDocument(String documentId) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      
      if (userId == null) {
        return await _getDocumentLocally(documentId);
      }

      final response = await _supabase
          .from('documents')
          .select()
          .eq('id', documentId)
          .eq('user_id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('DocumentService: Error getting document - $e');
      return await _getDocumentLocally(documentId);
    }
  }

  /// Get document from local SQLite
  static Future<Map<String, dynamic>?> _getDocumentLocally(String documentId) async {
    final Database db = await ChatDatabase.instance;
    final List<Map<String, Object?>> results = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    return results.isNotEmpty ? results.first as Map<String, dynamic> : null;
  }

  /// Get all documents for a conversation
  static Future<List<Map<String, dynamic>>> getDocumentsByConversation(
    String conversationId,
  ) async {
    try {
      final String? userId = AuthService.currentUser?.id;

      if (userId == null) {
        return await _getDocumentsLocally(conversationId);
      }

      final response = await _supabase
          .from('documents')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('DocumentService: Error getting documents - $e');
      return await _getDocumentsLocally(conversationId);
    }
  }

  /// Get documents from local SQLite
  static Future<List<Map<String, dynamic>>> _getDocumentsLocally(
    String conversationId,
  ) async {
    final Database db = await ChatDatabase.instance;
    final List<Map<String, Object?>> results = await db.query(
      'documents',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'updated_at DESC',
    );

    return results.map((row) => row as Map<String, dynamic>).toList();
  }

  /// Get document versions
  static Future<List<Map<String, dynamic>>> getDocumentVersions(
    String documentId,
  ) async {
    try {
      final String? userId = AuthService.currentUser?.id;

      if (userId == null) return [];

      final response = await _supabase
          .from('document_versions')
          .select()
          .eq('document_id', documentId)
          .eq('user_id', userId)
          .order('version_number', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('DocumentService: Error getting versions - $e');
      return [];
    }
  }

  /// Delete a document
  static Future<void> deleteDocument(String documentId) async {
    try {
      final String? userId = AuthService.currentUser?.id;

      if (userId != null) {
        await _supabase.from('documents').delete().eq('id', documentId);
      }

      // Also delete locally
      final Database db = await ChatDatabase.instance;
      await db.delete('documents', where: 'id = ?', whereArgs: [documentId]);
    } catch (e) {
      debugPrint('DocumentService: Error deleting document - $e');
    }
  }
}

