import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/chat_database.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final Rx<Map<String, dynamic>?> userProfile = Rx<Map<String, dynamic>?>(null);
  final RxString userName = ''.obs;
  final RxString userEmail = ''.obs;
  final RxString userAvatarUrl = ''.obs;
  final RxBool hasSeenOnboarding = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Don't block initialization - make async calls non-blocking
    _checkOnboardingStatus();
    _initializeAuth();
    _listenToAuthChanges();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      // Use getInstance without waiting to avoid blocking
      SharedPreferences.getInstance().then((prefs) {
        hasSeenOnboarding.value =
            prefs.getBool('has_seen_onboarding') ?? false;
      }).catchError((e) {
        debugPrint('Error checking onboarding status: $e');
        hasSeenOnboarding.value = false;
      });
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      hasSeenOnboarding.value = false;
    }
  }

  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
      hasSeenOnboarding.value = true;
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
    }
  }

  void _initializeAuth() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      currentUser.value = user;
      isLoggedIn.value = true;
      userEmail.value = user.email ?? '';
      _loadUserProfile();
    }
  }

  void _listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            currentUser.value = session!.user;
            isLoggedIn.value = true;
            userEmail.value = session.user.email ?? '';
            _loadUserProfile();
            
            // Sync conversations from Supabase when user signs in (non-blocking)
            // Schedule sync to happen asynchronously to avoid blocking UI
            Future.microtask(() async {
              try {
                final syncService = AuthService.syncService;
                await syncService.onLogin(session.user.id);
                debugPrint('✅ Conversations synced from Supabase after auth state change');
              } catch (e) {
                debugPrint('⚠️ Error syncing conversations after auth state change: $e');
                // Don't fail auth if sync fails
              }
            });
          }
          break;
        case AuthChangeEvent.signedOut:
          _clearUserData();
          break;
        case AuthChangeEvent.userUpdated:
          if (session?.user != null) {
            currentUser.value = session!.user;
            _loadUserProfile();
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    if (!isLoggedIn.value) return;

    try {
      final profile = await getUserProfile();
      if (profile != null) {
        userProfile.value = profile;
        userName.value =
            profile['full_name'] ??
            currentUser.value?.userMetadata?['full_name'] ??
            currentUser.value?.email?.split('@')[0] ??
            'User';
        userAvatarUrl.value = profile['avatar_url'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  void _clearUserData() {
    currentUser.value = null;
    isLoggedIn.value = false;
    userProfile.value = null;
    userName.value = '';
    userEmail.value = '';
    userAvatarUrl.value = '';
  }

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      isLoading.value = true;
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
        emailRedirectTo: null, // Disable email confirmation
      );
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // If login successful, sync conversations from Supabase in background
      // Don't block login - sync happens asynchronously
      if (response.user != null) {
        // Schedule sync to happen after login completes (non-blocking)
        Future.microtask(() async {
          try {
            final syncService = AuthService.syncService;
            await syncService.onLogin(response.user!.id);
            debugPrint('✅ Conversations synced from Supabase after login');
          } catch (e) {
            debugPrint('⚠️ Error syncing conversations after login: $e');
            // Don't fail login if sync fails
          }
        });
      }
      
      return response;
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.eidos://login-callback/',
      );
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      
      // Wipe all local data when user logs out
      await ChatDatabase.purgeAllLocal();
      
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      isLoading.value = true;
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isLoggedIn.value) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser.value!.id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    if (!isLoggedIn.value) throw Exception('User not logged in');

    try {
      isLoading.value = true;
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser.value!.id);

      // Reload profile after update
      await _loadUserProfile();
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    if (!isLoggedIn.value) throw Exception('User not logged in');

    try {
      isLoading.value = true;
      // First delete from profiles table (this will cascade)
      await _supabase.from('profiles').delete().eq('id', currentUser.value!.id);

      // Then delete from auth.users
      await _supabase.auth.admin.deleteUser(currentUser.value!.id);
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Upload profile picture to Supabase Storage
  Future<String> uploadProfilePicture(File imageFile) async {
    if (!isLoggedIn.value) throw Exception('User not logged in');

    try {
      isLoading.value = true;
      final userId = currentUser.value!.id;
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

      // Update user profile with new avatar URL
      await updateUserProfile(avatarUrl: publicUrl);

      return publicUrl;
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Delete profile picture from Supabase Storage
  Future<void> deleteProfilePicture() async {
    if (!isLoggedIn.value) throw Exception('User not logged in');

    try {
      isLoading.value = true;
      final userId = currentUser.value!.id;
      final filePath = '$userId/profile.jpg'; // Try common extensions

      // Try to delete the file (it might not exist)
      try {
        await _supabase.storage.from('profile-pictures').remove([filePath]);
      } catch (e) {
        // File might not exist, that's okay
        debugPrint('Profile picture not found or already deleted: $e');
      }

      // Update user profile to remove avatar URL
      await updateUserProfile(avatarUrl: null);
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
