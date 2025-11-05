import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'auth_service.dart';

class AdvancedSettingsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if auto-sync is enabled for the current user
  static Future<bool> isAutoSyncEnabled() async {
    try {
      final settings = await getAdvancedSettings();
      if (settings != null) {
        return settings['auto_sync'] as bool? ?? true;
      }
      return true; // Default to enabled
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error checking auto-sync - $e');
      return true; // Default to enabled on error
    }
  }

  /// Get or create advanced settings for the current user
  static Future<Map<String, dynamic>?> getAdvancedSettings() async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        debugPrint('AdvancedSettingsService: No user ID, cannot fetch settings');
        return null;
      }

      final response = await _supabase
          .from('advanced_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        debugPrint('AdvancedSettingsService: Found settings for user $userId');
        return Map<String, dynamic>.from(response);
      }

      // Create default settings if none exist
      debugPrint('AdvancedSettingsService: No settings found, creating defaults');
      return await createDefaultSettings(userId);
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error getting settings - $e');
      return null;
    }
  }

  /// Create default advanced settings for a user
  static Future<Map<String, dynamic>?> createDefaultSettings(String userId) async {
    try {
      final defaultSettings = {
        'user_id': userId,
        'max_tokens': 1000,
        'apply_to_all_chats': true,
        'auto_clear_cache': false,
        'enable_analytics': true,
        'enable_crash_reports': true,
        'auto_sync': true,
      };

      final response = await _supabase
          .from('advanced_settings')
          .insert(defaultSettings)
          .select()
          .single();

      debugPrint('AdvancedSettingsService: Created default settings');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error creating default settings - $e');
      return null;
    }
  }

  /// Save advanced settings
  static Future<void> saveAdvancedSettings({
    required int maxTokens,
    required bool applyToAllChats,
    required bool autoClearCache,
    required bool enableAnalytics,
    required bool enableCrashReports,
    required bool autoSync,
  }) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        debugPrint('AdvancedSettingsService: No user ID, cannot save settings');
        return;
      }

      // Try to update with all settings including auto_sync
      final allSettings = <String, dynamic>{
        'max_tokens': maxTokens,
        'apply_to_all_chats': applyToAllChats,
        'auto_clear_cache': autoClearCache,
        'enable_analytics': enableAnalytics,
        'enable_crash_reports': enableCrashReports,
        'auto_sync': autoSync,
      };

      try {
        // Try to update with all fields including auto_sync
        final updateResponse = await _supabase
            .from('advanced_settings')
            .update(allSettings)
            .eq('user_id', userId)
            .select();

        // If no rows were updated, insert new settings
        if (updateResponse.isEmpty) {
          await _supabase
              .from('advanced_settings')
              .insert({
                'user_id': userId,
                ...allSettings,
              });
          debugPrint('AdvancedSettingsService: Inserted new settings');
        } else {
          debugPrint('AdvancedSettingsService: Updated existing settings');
        }
      } catch (e) {
        // If auto_sync column doesn't exist, update without it
        if (e.toString().contains('auto_sync') || 
            e.toString().contains('PGRST204') ||
            e.toString().contains('Could not find')) {
          debugPrint('AdvancedSettingsService: auto_sync column not found, updating without it');
          debugPrint('AdvancedSettingsService: Please run the migration SQL: ALTER TABLE public.advanced_settings ADD COLUMN IF NOT EXISTS auto_sync BOOLEAN NOT NULL DEFAULT TRUE;');
          
          // Update without auto_sync
          final settingsWithoutAutoSync = <String, dynamic>{
            'max_tokens': maxTokens,
            'apply_to_all_chats': applyToAllChats,
            'auto_clear_cache': autoClearCache,
            'enable_analytics': enableAnalytics,
            'enable_crash_reports': enableCrashReports,
          };
          
          final updateResponse = await _supabase
              .from('advanced_settings')
              .update(settingsWithoutAutoSync)
              .eq('user_id', userId)
              .select();

          // If no rows were updated, insert new settings
          if (updateResponse.isEmpty) {
            await _supabase
                .from('advanced_settings')
                .insert({
                  'user_id': userId,
                  ...settingsWithoutAutoSync,
                });
            debugPrint('AdvancedSettingsService: Inserted new settings (without auto_sync)');
          } else {
            debugPrint('AdvancedSettingsService: Updated existing settings (without auto_sync)');
          }
        } else {
          debugPrint('AdvancedSettingsService: Error saving settings - $e');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error saving settings - $e');
      rethrow;
    }
  }

  /// Submit a crash report
  static Future<bool> submitCrashReport({
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      
      // Get device and app info
      final deviceInfo = await _getDeviceInfo();
      final appVersion = await _getAppVersion();

      final crashReport = {
        if (userId != null) 'user_id': userId,
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace,
        'device_info': deviceInfo,
        if (appVersion != null) 'app_version': appVersion['version'],
        if (appVersion != null) 'os_version': deviceInfo['os_version'],
        if (additionalInfo != null) 'additional_info': additionalInfo,
        'status': 'pending',
      };

      await _supabase.from('crash_reports').insert(crashReport);
      debugPrint('AdvancedSettingsService: Crash report submitted successfully');
      return true;
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error submitting crash report - $e');
      return false;
    }
  }

  /// Get device information
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        deviceData = {
          'platform': 'android',
          'os_version': 'Android',
        };
      } else if (Platform.isIOS) {
        deviceData = {
          'platform': 'ios',
          'os_version': 'iOS',
        };
      } else if (Platform.isMacOS) {
        deviceData = {
          'platform': 'macos',
          'os_version': 'macOS',
        };
      } else if (Platform.isWindows) {
        deviceData = {
          'platform': 'windows',
          'os_version': 'Windows',
        };
      } else if (Platform.isLinux) {
        deviceData = {
          'platform': 'linux',
          'os_version': 'Linux',
        };
      } else {
        deviceData = {
          'platform': 'unknown',
          'os_version': 'unknown',
        };
      }

      return deviceData;
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error getting device info - $e');
      return {'platform': 'unknown', 'os_version': 'unknown'};
    }
  }

  /// Get app version information
  static Future<Map<String, String>?> _getAppVersion() async {
    try {
      // Basic version info - can be enhanced with package_info_plus if needed
      return {
        'version': '1.0.0',
        'build_number': '1',
        'app_name': 'Eidos',
      };
    } catch (e) {
      debugPrint('AdvancedSettingsService: Error getting app version - $e');
      return null;
    }
  }
}

