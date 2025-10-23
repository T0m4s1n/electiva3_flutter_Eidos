import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

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

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isLoggedIn) return null;

    try {
      final response = await _supabase
          .from('users')
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
    String? bio,
    String? avatarUrl,
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    String? language,
  }) async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (notificationsEnabled != null) {
        updates['notifications_enabled'] = notificationsEnabled;
      }
      if (darkModeEnabled != null) {
        updates['dark_mode_enabled'] = darkModeEnabled;
      }
      if (language != null) updates['language'] = language;

      await _supabase.from('users').update(updates).eq('id', currentUser!.id);
    } catch (e) {
      rethrow;
    }
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    if (!isLoggedIn) throw Exception('User not logged in');

    try {
      // First delete from users table (this will cascade)
      await _supabase.from('users').delete().eq('id', currentUser!.id);

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
}

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.bio,
    this.avatarUrl,
    required this.notificationsEnabled,
    required this.darkModeEnabled,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'],
      bio: map['bio'],
      avatarUrl: map['avatar_url'],
      notificationsEnabled: map['notifications_enabled'] ?? true,
      darkModeEnabled: map['dark_mode_enabled'] ?? false,
      language: map['language'] ?? 'English',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'notifications_enabled': notificationsEnabled,
      'dark_mode_enabled': darkModeEnabled,
      'language': language,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
