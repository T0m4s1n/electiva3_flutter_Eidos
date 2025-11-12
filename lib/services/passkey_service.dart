import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasskeyService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const _uuid = Uuid();
  static const _secureStorage = FlutterSecureStorage();

  static Future<bool> isDeviceSupported() async {
    try {
      final bool isSupported = await _localAuth.isDeviceSupported();
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return isSupported && canCheckBiometrics;
    } catch (e) {
      debugPrint('Error checking device support: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> registerPasskey({
    required String userId,
    required String email,
    required String password,
    String? deviceName,
  }) async {
    try {
      debugPrint('Starting passkey registration for user: $userId, email: $email');
      
      // Check device support
      if (!await isDeviceSupported()) {
        debugPrint('Device does not support biometric authentication');
        throw Exception('Device does not support biometric authentication');
      }

      debugPrint('Device supports biometrics, requesting authentication...');
      
      // Request biometric authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to register a passkey for secure login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        debugPrint('Biometric authentication was cancelled or failed');
        throw Exception('Biometric authentication failed');
      }

      debugPrint('Biometric authentication successful, generating passkey...');

      // Generate passkey identifiers
      final passkeyId = _uuid.v4();
      final credentialId = _uuid.v4();
      final publicKey = _generatePublicKey(userId, passkeyId);

      final deviceInfo = _getDeviceInfo();
      final finalDeviceName = deviceName ?? deviceInfo['name'] ?? 'Unknown Device';

      debugPrint('Generated passkey ID: $passkeyId, credential ID: $credentialId');
      
      // Verify user exists in auth.users (this should always be true if logged in)
      try {
        final userCheck = await _supabase.auth.getUser();
        if (userCheck.user == null || userCheck.user!.id != userId) {
          debugPrint('User ID mismatch or user not found in auth');
          throw Exception('User authentication error. Please log out and log back in.');
        }
        debugPrint('User verified in auth system');
      } catch (authError) {
        debugPrint('Error verifying user: $authError');
        throw Exception('Authentication error. Please log out and log back in.');
      }
      
      debugPrint('Inserting passkey into database...');

      // Insert passkey into Supabase
      try {
        final response = await _supabase.from('passkeys').insert({
          'user_id': userId,
          'passkey_id': passkeyId,
          'credential_id': credentialId,
          'public_key': publicKey,
          'device_name': finalDeviceName,
          'device_type': deviceInfo['type'],
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();

        debugPrint('Passkey inserted successfully into database');

        // Store password securely for later authentication
        try {
          await _secureStorage.write(
            key: 'passkey_password_$passkeyId',
            value: password,
          );
          
          await _secureStorage.write(
            key: 'passkey_email_$passkeyId',
            value: email,
          );
          
          debugPrint('Password and email stored securely');
        } catch (storageError) {
          debugPrint('Error storing password in secure storage: $storageError');
          // If secure storage fails, try to delete the passkey from database
          try {
            await _supabase
                .from('passkeys')
                .update({'is_active': false})
                .eq('passkey_id', passkeyId);
          } catch (deleteError) {
            debugPrint('Error cleaning up passkey after storage failure: $deleteError');
          }
          throw Exception('Failed to store passkey credentials securely');
        }

        debugPrint('Passkey registration completed successfully');
        return response;
      } on PostgrestException catch (e) {
        debugPrint('Database error during passkey registration: ${e.message}');
        debugPrint('Error code: ${e.code}, details: ${e.details}');
        if (e.code == '23503') {
          throw Exception('User not found. Please ensure you are logged in and your profile exists.');
        } else if (e.code == '23505') {
          throw Exception('A passkey with this credential already exists.');
        } else if (e.code == '42501') {
          throw Exception('Permission denied. Please check your account permissions.');
        } else {
          throw Exception('Database error: ${e.message}');
        }
      } catch (e) {
        debugPrint('Unexpected error during database insert: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('Error registering passkey: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> authenticateWithPasskey({
    required String email,
  }) async {
    try {
      if (!await isDeviceSupported()) {
        throw Exception('Device does not support biometric authentication');
      }

      final userResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .single();

      final userId = userResponse['id'] as String;

      final passkeysResponse = await _supabase
          .from('passkeys')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      if (passkeysResponse.isEmpty) {
        throw Exception('No passkeys found for this user');
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in with passkey',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }

      final passkey = passkeysResponse.first;
      await _supabase
          .from('passkeys')
          .update({'last_used_at': DateTime.now().toIso8601String()})
          .eq('id', passkey['id'] as String);

      final passkeyId = passkey['passkey_id'] as String;
      final storedPassword = await _secureStorage.read(
        key: 'passkey_password_$passkeyId',
      );

      if (storedPassword == null) {
        throw Exception('Password not found for passkey');
      }

      return {
        'user_id': userId,
        'email': email,
        'passkey_id': passkeyId,
        'password': storedPassword,
      };
    } catch (e) {
      debugPrint('Error authenticating with passkey: $e');
      rethrow;
    }
  }

  static Future<bool> hasPasskeys(String userId) async {
    try {
      final response = await _supabase
          .from('passkeys')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking passkeys: $e');
      return false;
    }
  }

  static Future<bool> hasPasskeysForEmail(String email) async {
    try {
      debugPrint('🔍 Checking passkeys for email: $email');
      
      // First, check if user exists in profiles table
      final userResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle(); // Use maybeSingle to avoid error if user doesn't exist

      if (userResponse == null) {
        debugPrint('❌ User not found in profiles for email: $email');
        return false;
      }

      final userId = userResponse['id'] as String;
      debugPrint('✅ Found user ID: $userId for email: $email');
      
      // Check if user has active passkeys
      final hasPasskeysResult = await hasPasskeys(userId);
      debugPrint('${hasPasskeysResult ? "✅" : "❌"} User $userId has passkeys: $hasPasskeysResult');
      
      return hasPasskeysResult;
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking passkeys for email $email: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getUserPasskeys(String userId) async {
    try {
      final response = await _supabase
          .from('passkeys')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_used_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user passkeys: $e');
      return [];
    }
  }

  static Future<void> deletePasskey(String passkeyId) async {
    try {
      final passkeyResponse = await _supabase
          .from('passkeys')
          .select('passkey_id')
          .eq('passkey_id', passkeyId)
          .single();
      
      final storedPasskeyId = passkeyResponse['passkey_id'] as String;
      
      await _supabase
          .from('passkeys')
          .update({'is_active': false})
          .eq('passkey_id', passkeyId);
      
      await _secureStorage.delete(key: 'passkey_password_$storedPasskeyId');
      await _secureStorage.delete(key: 'passkey_email_$storedPasskeyId');
    } catch (e) {
      debugPrint('Error deleting passkey: $e');
      rethrow;
    }
  }

  static String _generatePublicKey(String userId, String passkeyId) {
    final key = '$userId:$passkeyId:${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(key);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  static Map<String, String> _getDeviceInfo() {
    if (Platform.isAndroid) {
      return {
        'name': 'Android Device',
        'type': 'android',
      };
    } else if (Platform.isIOS) {
      return {
        'name': 'iOS Device',
        'type': 'ios',
      };
    } else {
      return {
        'name': 'Unknown Device',
        'type': 'unknown',
      };
    }
  }
}
