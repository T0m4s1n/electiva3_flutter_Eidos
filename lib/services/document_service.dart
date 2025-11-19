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
    String? changeSummary,
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
          changeSummary: changeSummary,
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
    String? changeSummary,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    int currentVersion = 1;
    String oldContent = '';

    // Get current version from Supabase if available
    try {
      final currentDoc = await _supabase
          .from('documents')
          .select()
          .eq('id', documentId)
          .single();

      currentVersion = currentDoc['version_number'] as int;
      oldContent = currentDoc['content'] as String;
    } catch (e) {
      // If Supabase fails, try local storage
      debugPrint('DocumentService: Could not get version from Supabase, trying local: $e');
      final localDoc = await _getDocumentLocally(documentId);
      if (localDoc != null) {
        currentVersion = localDoc['version_number'] as int? ?? 1;
        oldContent = localDoc['content'] as String? ?? '';
      }
    }

    final int newVersion = currentVersion + 1;

    // Save the OLD version content to document_versions table (both Supabase and local)
    final versionId = IdGenerator.generateConversationId();
    
    // Save locally first
    await _saveVersionLocally(
      versionId: versionId,
      documentId: documentId,
      content: oldContent,
      versionNumber: currentVersion,
      userId: userId,
      changeSummary: changeSummary,
    );

    // Try to save to Supabase if user is authenticated
    if (userId.isNotEmpty) {
      try {
        await _supabase.from('document_versions').insert({
          'id': versionId,
          'document_id': documentId,
          'user_id': userId,
          'content': oldContent,
          'version_number': currentVersion,
          'created_at': now,
          'created_by': userId,
          'change_summary': changeSummary,
        });

        // Upload old version to storage
        await _uploadToStorage(
          userId: userId,
          documentId: documentId,
          content: oldContent,
          version: currentVersion,
        );
      } catch (e) {
        debugPrint('DocumentService: Failed to save version to Supabase: $e');
      }
    }

    // Update document to new version (both Supabase and local)
    // Update local first
    await _updateDocumentLocally(
      documentId: documentId,
      content: content,
      versionNumber: newVersion,
    );

    // Try to update Supabase
    if (userId.isNotEmpty) {
      try {
        await _supabase
            .from('documents')
            .update({
              'content': content,
              'version_number': newVersion,
              'is_current_version': true,
              'updated_at': now,
            })
            .eq('id', documentId);

        // Upload new version to storage
        await _uploadToStorage(
          userId: userId,
          documentId: documentId,
          content: content,
          version: newVersion,
        );
      } catch (e) {
        debugPrint('DocumentService: Failed to update document in Supabase: $e');
      }
    }

    debugPrint('DocumentService: Created version $newVersion (saved version $currentVersion to history)');
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
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true, // Allow overwriting if version already exists
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
    
    // Check if document exists to determine if we need to create a version
    final existingDoc = await _getDocumentLocally(docId);
    bool isNewDocument = existingDoc == null;
    
    if (!isNewDocument && documentId != null) {
      // This is an update - save current version before updating
      final oldContent = existingDoc['content'] as String? ?? '';
      final oldVersion = existingDoc['version_number'] as int? ?? 1;
      
      if (oldContent.isNotEmpty && oldContent != content) {
        // Save old version
        await _saveVersionLocally(
          versionId: IdGenerator.generateConversationId(),
          documentId: docId,
          content: oldContent,
          versionNumber: oldVersion,
          userId: userId,
        );
      }
    }

    // Update or insert document
    await db.insert(
      'documents',
      {
        'id': docId,
        'conversation_id': conversationId,
        'user_id': userId,
        'title': title,
        'content': content,
        'is_current_version': 1,
        'version_number': isNewDocument ? 1 : ((existingDoc['version_number'] as int? ?? 1) + 1),
        'created_at': existingDoc?['created_at'] as String? ?? now,
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

  /// Get all documents for the current user
  static Future<List<Map<String, dynamic>>> getAllDocuments() async {
    try {
      final String? userId = AuthService.currentUser?.id;

      if (userId == null) {
        return await _getAllDocumentsLocally();
      }

      // Try to get from Supabase first
      try {
        final response = await _supabase
            .from('documents')
            .select()
            .eq('user_id', userId)
            .eq('is_current_version', true)
            .order('updated_at', ascending: false);

        final supabaseDocs = List<Map<String, dynamic>>.from(response);
        
        // Also get local documents
        final localDocs = await _getAllDocumentsLocally();
        
        // Merge documents, avoiding duplicates (prefer Supabase if both exist)
        final Map<String, Map<String, dynamic>> docMap = {};
        
        // Add local documents first
        for (final doc in localDocs) {
          final docId = doc['id'] as String? ?? '';
          if (docId.isNotEmpty) {
            docMap[docId] = doc;
          }
        }
        
        // Override with Supabase documents if they exist
        for (final doc in supabaseDocs) {
          final docId = doc['id'] as String? ?? '';
          if (docId.isNotEmpty) {
            docMap[docId] = doc;
          }
        }

        // Convert back to list and sort
        final mergedDocs = docMap.values.toList()
          ..sort((a, b) {
            final aDate = a['updated_at'] as String? ?? '';
            final bDate = b['updated_at'] as String? ?? '';
            return bDate.compareTo(aDate); // Descending order
          });

        return mergedDocs;
      } catch (e) {
        debugPrint('DocumentService: Error getting documents from Supabase - $e');
        return await _getAllDocumentsLocally();
      }
    } catch (e) {
      debugPrint('DocumentService: Error getting all documents - $e');
      return await _getAllDocumentsLocally();
    }
  }

  /// Get all documents from local SQLite
  static Future<List<Map<String, dynamic>>> _getAllDocumentsLocally() async {
    try {
      final Database db = await ChatDatabase.instance;
      final String? userId = AuthService.currentUser?.id;
      
      // Get all documents for the current user, or all documents if no user
      final List<Map<String, Object?>> results;
      if (userId != null && userId.isNotEmpty) {
        results = await db.query(
          'documents',
          where: 'user_id = ? AND is_current_version = ?',
          whereArgs: [userId, 1],
          orderBy: 'updated_at DESC',
        );
      } else {
        // If no user, get all documents (for offline mode)
        results = await db.query(
          'documents',
          where: 'is_current_version = ?',
          whereArgs: [1],
          orderBy: 'updated_at DESC',
        );
      }

      return results.map((row) => row as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('DocumentService: Error getting all documents locally - $e');
      return [];
    }
  }

  /// Create initial version 1.0 for a document if it doesn't exist
  static Future<void> createInitialVersion1IfNeeded(String documentId) async {
    try {
      // Check if version 1.0 already exists
      final existingVersions = await getDocumentVersions(documentId);
      final hasVersion1 = existingVersions.any((v) => (v['version_number'] as int? ?? 0) == 1);
      
      if (hasVersion1) {
        debugPrint('DocumentService: Version 1.0 already exists for document $documentId');
        return;
      }
      
      // Get the document content
      final doc = await getDocument(documentId);
      if (doc == null) {
        debugPrint('DocumentService: Document not found for ID $documentId');
        return;
      }
      
      final content = doc['content'] as String? ?? '';
      if (content.isEmpty) {
        debugPrint('DocumentService: Document content is empty, skipping version 1.0 creation');
        return;
      }
      
      final String? userId = AuthService.currentUser?.id;
      final versionId = IdGenerator.generateConversationId();
      final String now = DateTime.now().toUtc().toIso8601String();
      
      // Save version 1.0 locally
      await _saveVersionLocally(
        versionId: versionId,
        documentId: documentId,
        content: content,
        versionNumber: 1,
        userId: userId,
        changeSummary: 'Initial version 1.0',
      );
      
      // Try to save to Supabase if user is authenticated
      if (userId != null && userId.isNotEmpty) {
        try {
          await _supabase.from('document_versions').insert({
            'id': versionId,
            'document_id': documentId,
            'user_id': userId,
            'content': content,
            'version_number': 1,
            'created_at': now,
            'created_by': userId,
            'change_summary': 'Initial version 1.0',
          });
          
          // Upload version to storage
          await _uploadToStorage(
            userId: userId,
            documentId: documentId,
            content: content,
            version: 1,
          );
          
          debugPrint('DocumentService: Created initial version 1.0 for document $documentId');
        } catch (e) {
          debugPrint('DocumentService: Failed to save version 1.0 to Supabase: $e');
          // Continue even if Supabase fails - local version is saved
        }
      }
    } catch (e) {
      debugPrint('DocumentService: Error creating initial version 1.0: $e');
    }
  }

  /// Get document versions (from both Supabase and local storage)
  static Future<List<Map<String, dynamic>>> getDocumentVersions(
    String documentId,
  ) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      List<Map<String, dynamic>> versions = [];

      // Try to get from Supabase first if user is authenticated
      if (userId != null && userId.isNotEmpty) {
        try {
          final response = await _supabase
              .from('document_versions')
              .select()
              .eq('document_id', documentId)
              .eq('user_id', userId)
              .order('version_number', ascending: false);

          versions = List<Map<String, dynamic>>.from(response);
        } catch (e) {
          debugPrint('DocumentService: Error getting versions from Supabase - $e');
        }
      }

      // Always get from local storage
      final localVersions = await _getVersionsLocally(documentId);
      
      // Merge versions, avoiding duplicates (prefer Supabase if both exist)
      final Map<int, Map<String, dynamic>> versionMap = {};
      
      // Add local versions first
      for (final version in localVersions) {
        final versionNum = version['version_number'] as int? ?? 0;
        versionMap[versionNum] = version;
      }
      
      // Override with Supabase versions if they exist
      for (final version in versions) {
        final versionNum = version['version_number'] as int? ?? 0;
        versionMap[versionNum] = version;
      }

      // Convert back to list and sort
      final mergedVersions = versionMap.values.toList()
        ..sort((a, b) {
          final aNum = a['version_number'] as int? ?? 0;
          final bNum = b['version_number'] as int? ?? 0;
          return bNum.compareTo(aNum); // Descending order
        });

      return mergedVersions;
    } catch (e) {
      debugPrint('DocumentService: Error getting versions - $e');
      // Fallback to local only
      return await _getVersionsLocally(documentId);
    }
  }

  /// Save version locally
  static Future<void> _saveVersionLocally({
    required String versionId,
    required String documentId,
    required String content,
    required int versionNumber,
    required String? userId,
    String? changeSummary,
  }) async {
    try {
      final Database db = await ChatDatabase.instance;
      final String now = DateTime.now().toUtc().toIso8601String();
      
      // Get conversation_id from document
      final doc = await _getDocumentLocally(documentId);
      final conversationId = doc?['conversation_id'] as String? ?? '';

      await db.insert(
        'document_versions',
        {
          'id': versionId,
          'document_id': documentId,
          'conversation_id': conversationId,
          'user_id': userId,
          'content': content,
          'version_number': versionNumber,
          'created_at': now,
          'created_by': userId,
          'change_summary': changeSummary,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('DocumentService: Saved version $versionNumber locally');
    } catch (e) {
      debugPrint('DocumentService: Error saving version locally - $e');
    }
  }

  /// Get versions from local SQLite
  static Future<List<Map<String, dynamic>>> _getVersionsLocally(
    String documentId,
  ) async {
    try {
      final Database db = await ChatDatabase.instance;
      final List<Map<String, Object?>> results = await db.query(
        'document_versions',
        where: 'document_id = ?',
        whereArgs: [documentId],
        orderBy: 'version_number DESC',
      );

      return results.map((row) => row as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('DocumentService: Error getting versions locally - $e');
      return [];
    }
  }

  /// Update document locally
  static Future<void> _updateDocumentLocally({
    required String documentId,
    required String content,
    required int versionNumber,
  }) async {
    try {
      final Database db = await ChatDatabase.instance;
      final String now = DateTime.now().toUtc().toIso8601String();

      await db.update(
        'documents',
        {
          'content': content,
          'version_number': versionNumber,
          'is_current_version': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [documentId],
      );

      debugPrint('DocumentService: Updated document locally to version $versionNumber');
    } catch (e) {
      debugPrint('DocumentService: Error updating document locally - $e');
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

