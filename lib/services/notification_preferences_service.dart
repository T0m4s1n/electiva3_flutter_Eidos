import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class NotificationPreferencesService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get or create notification preferences for the current user
  static Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        debugPrint('NotificationPreferencesService: No user ID, cannot fetch preferences');
        return null;
      }

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        debugPrint('NotificationPreferencesService: Found preferences for user $userId');
        return Map<String, dynamic>.from(response);
      }

      // Create default preferences if none exist
      debugPrint('NotificationPreferencesService: No preferences found, creating defaults');
      return await createDefaultPreferences(userId);
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error getting preferences - $e');
      return null;
    }
  }

  /// Create default notification preferences for a user
  static Future<Map<String, dynamic>?> createDefaultPreferences(String userId) async {
    try {
      final defaultPreferences = {
        'user_id': userId,
        'enable_push': true,
        'enable_in_app': true,
        'enable_sound': true,
        'enable_vibration': true,
        'quiet_hours_enabled': false,
        'quiet_start_hour': 22,
        'quiet_start_minute': 0,
        'quiet_end_hour': 7,
        'quiet_end_minute': 0,
      };

      final response = await _supabase
          .from('notification_preferences')
          .insert(defaultPreferences)
          .select()
          .single();

      debugPrint('NotificationPreferencesService: Created default preferences');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error creating default preferences - $e');
      return null;
    }
  }

  /// Save notification preferences
  static Future<void> saveNotificationPreferences({
    required bool enablePush,
    required bool enableInApp,
    required bool enableSound,
    required bool enableVibration,
    required bool quietHoursEnabled,
    required int quietStartHour,
    required int quietStartMinute,
    required int quietEndHour,
    required int quietEndMinute,
  }) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        debugPrint('NotificationPreferencesService: No user ID, cannot save preferences');
        return;
      }

      final preferences = {
        'enable_push': enablePush,
        'enable_in_app': enableInApp,
        'enable_sound': enableSound,
        'enable_vibration': enableVibration,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_start_hour': quietStartHour,
        'quiet_start_minute': quietStartMinute,
        'quiet_end_hour': quietEndHour,
        'quiet_end_minute': quietEndMinute,
      };

      // Try to update existing preferences
      final updateResponse = await _supabase
          .from('notification_preferences')
          .update(preferences)
          .eq('user_id', userId)
          .select();

      // If no rows were updated, insert new preferences
      if (updateResponse.isEmpty) {
        await _supabase
            .from('notification_preferences')
            .insert({
              'user_id': userId,
              ...preferences,
            });
        debugPrint('NotificationPreferencesService: Inserted new preferences');
      } else {
        debugPrint('NotificationPreferencesService: Updated existing preferences');
      }
    } catch (e) {
      debugPrint('NotificationPreferencesService: Error saving preferences - $e');
      rethrow;
    }
  }
}

