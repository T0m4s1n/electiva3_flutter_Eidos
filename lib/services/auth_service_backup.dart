import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';
import 'passkey_service.dart' as passkey;

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final SyncService _syncService = SyncService(_supabase);

  // Get current user
  static User? get currentUser => _supabase.auth.currentUser;

  // Check if user is logged in
  static bool get isLoggedIn => currentUser != null;

  // Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
        emailRedirectTo: null, // Disable email confirmation
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Si el login es exitoso, sincronizar datos locales
      if (response.user != null) {
        await _syncService.onLogin(response.user!.id);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google (placeholder - requires additional setup)
  static Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.eidos://login-callback/',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      // Primero sincronizar y limpiar datos locales
      await _syncService.onLogout();

      // Luego cerrar sesión en Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Update current user's password (requires active session)
  static Future<void> updatePassword(String newPassword) async {
    if (!isLoggedIn) throw Exception('User not logged in');
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      rethrow;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isLoggedIn) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('profiles').update(updates).eq('id', currentUser!.id);
    } catch (e) {
      rethrow;
    }
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      // First delete from profiles table (this will cascade)
      await _supabase.from('profiles').delete().eq('id', currentUser!.id);

      // Then delete from auth.users
      await _supabase.auth.admin.deleteUser(currentUser!.id);
    } catch (e) {
      rethrow;
    }
  }

  // Upload profile picture to Supabase Storage
  static Future<String> uploadProfilePicture(File imageFile) async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      final userId = currentUser!.id;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = 'profile.$fileExtension';
      final filePath = '$userId/$fileName';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _supabase.storage
          .from('profile-pictures')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true, // This allows overwriting existing files
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profile-pictures')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Delete profile picture from Supabase Storage
  static Future<void> deleteProfilePicture() async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      final userId = currentUser!.id;
      final filePath = '$userId/profile.jpg'; // Try common extensions

      // Try to delete the file (it might not exist)
      try {
        await _supabase.storage.from('profile-pictures').remove([filePath]);
      } catch (e) {
        // File might not exist, that's okay
        debugPrint('Profile picture not found or already deleted: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // Sincronización manual de datos pendientes
  static Future<void> syncPendingData() async {
    if (!isLoggedIn) return;
    await _syncService.syncPending();
  }

  // Manual full sync: push all local data and pull all cloud data
  static Future<void> manualSync() async {
    if (!isLoggedIn) {
      throw Exception('User not logged in');
    }
    await _syncService.manualSync();
  }

  // Obtener el servicio de sincronización para uso avanzado
  static SyncService get syncService => _syncService;

  // Sign in with passkey
  // Note: This uses biometric authentication to verify the user,
  // then signs them in with Supabase using their stored password
  static Future<AuthResponse> signInWithPasskey({
    required String email,
  }) async {
    try {
      // Authenticate with passkey (biometric verification + retrieve stored password)
      final passkeyAuth = await passkey.PasskeyService.authenticateWithPasskey(email: email);
      
      // After biometric verification, sign in with Supabase using stored password
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: passkeyAuth['password'] as String,
      );

      // Sync conversations after successful login
      if (response.user != null) {
        await _syncService.onLogin(response.user!.id);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Register passkey for current user
  static Future<Map<String, dynamic>> registerPasskey({
    String? deviceName,
    required String password, // Store password securely for passkey login
  }) async {
    if (!isLoggedIn) throw Exception('User not logged in');
    try {
      final email = currentUser!.email ?? '';
      return await passkey.PasskeyService.registerPasskey(
        userId: currentUser!.id,
        email: email,
        password: password,
        deviceName: deviceName,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has passkeys
  static Future<bool> hasPasskeys() async {
    if (!isLoggedIn) return false;
    return await passkey.PasskeyService.hasPasskeys(currentUser!.id);
  }

  // Get user's passkeys
  static Future<List<Map<String, dynamic>>> getUserPasskeys() async {
    if (!isLoggedIn) return [];
    return await passkey.PasskeyService.getUserPasskeys(currentUser!.id);
  }

  // Delete passkey
  static Future<void> deletePasskey(String passkeyId) async {
    if (!isLoggedIn) throw Exception('User not logged in');
    await passkey.PasskeyService.deletePasskey(passkeyId);
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'],
      avatarUrl: map['avatar_url'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
