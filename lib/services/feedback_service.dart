import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'auth_service.dart';

class FeedbackService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Submit feedback message to Supabase
  static Future<String> submitFeedback({
    required String type,
    required String severity,
    required String title,
    required String description,
    String? contactEmail,
    List<File>? attachments,
  }) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      
      // Upload attachments to Supabase storage if any
      List<String>? attachmentUrls;
      if (attachments != null && attachments.isNotEmpty) {
        attachmentUrls = await _uploadAttachments(attachments);
      }

      // Prepare feedback data
      final feedbackData = {
        'user_id': userId,
        'type': type,
        'severity': severity,
        'title': title,
        'description': description,
        'contact_email': contactEmail?.trim().isEmpty == true ? null : contactEmail?.trim(),
        'attachment_urls': attachmentUrls,
        'status': 'pending',
      };

      // Insert feedback message
      final response = await _supabase
          .from('feedback_messages')
          .insert(feedbackData)
          .select()
          .single();

      final feedbackId = response['id'] as String;
      debugPrint('FeedbackService: Feedback submitted successfully with ID: $feedbackId');
      return feedbackId;
    } catch (e) {
      debugPrint('FeedbackService: Error submitting feedback - $e');
      rethrow;
    }
  }

  /// Upload attachment files to Supabase storage
  /// Note: The 'feedback-attachments' bucket must be created in Supabase Storage
  static Future<List<String>> _uploadAttachments(List<File> attachments) async {
    final List<String> urls = [];
    final String? userId = AuthService.currentUser?.id;
    final String folder = userId != null ? 'feedback/$userId' : 'feedback/anonymous';

    try {
      for (int i = 0; i < attachments.length; i++) {
        final file = attachments[i];
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i${path.extension(file.path)}';
        final filePath = '$folder/$fileName';

        // Read file bytes
        final fileBytes = await file.readAsBytes();

        // Upload to Supabase storage
        // Note: If bucket doesn't exist, create it in Supabase Storage dashboard
        try {
          await _supabase.storage
              .from('feedback-attachments')
              .uploadBinary(filePath, fileBytes);

          // Get public URL
          final url = _supabase.storage
              .from('feedback-attachments')
              .getPublicUrl(filePath);

          urls.add(url);
          debugPrint('FeedbackService: Uploaded attachment $i: $url');
        } catch (e) {
          debugPrint('FeedbackService: Error uploading attachment $i - $e');
          debugPrint('FeedbackService: Note - Make sure the "feedback-attachments" bucket exists in Supabase Storage');
          // Continue with other attachments even if one fails
        }
      }
    } catch (e) {
      debugPrint('FeedbackService: Error in attachment upload process - $e');
      // Return whatever URLs we successfully uploaded
    }

    return urls;
  }

  /// Get feedback messages for the current user
  static Future<List<Map<String, dynamic>>> getMyFeedback() async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('feedback_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('FeedbackService: Error getting feedback - $e');
      return [];
    }
  }
}

