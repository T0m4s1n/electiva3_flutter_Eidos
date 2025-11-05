import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/app_controller.dart';
import '../controllers/chat_controller.dart';
import '../widgets/animated_header.dart';
import '../widgets/loading_screen.dart';
import '../widgets/conversations_list.dart';
import 'auth_page.dart';
import 'edit_profile_page.dart';
import 'chat_page.dart';
import 'onboarding_page.dart';
import '../routes/app_routes.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import '../services/translation_service.dart';
import '../widgets/theme_change_loader.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _headerKey = GlobalKey();
  final TextEditingController _chatSearchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final NavigationController navController = Get.find<NavigationController>();
    final AppController appController = Get.find<AppController>();

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Obx(() {
      // Show onboarding if user hasn't seen it
      if (!authController.hasSeenOnboarding.value) {
        return const OnboardingPage();
      }

      // Show auth if not logged in
      if (!authController.isLoggedIn.value) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const AuthPage(),
        );
      }

      // Show loading screen if initial loading
      if (appController.isInitialLoading.value) {
        return LoadingScreen(
          message: TranslationService.translate('welcome_to_eidos'),
          duration: const Duration(milliseconds: 300),
        );
      }

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Theme change loader overlay (fullscreen)
              Positioned.fill(
                child: ThemeChangeLoader(),
              ),
              Column(
                children: [
                  // Custom animated header - only show when not in edit profile
                  if (!navController.showEditProfile.value)
                    AnimatedHeader(
                      key: _headerKey,
                      isLoggedIn: authController.isLoggedIn.value,
                      userName: authController.userName.value,
                      userEmail: authController.userEmail.value,
                      userAvatarUrl:
                          authController.userAvatarUrl.value.isNotEmpty
                          ? authController.userAvatarUrl.value
                          : null,
                      onLogin: () => authController.signOut(),
                      onLogout: () => authController.signOut(),
                      onEditProfile: () => navController.showEditProfileView(),
                      onPreferences: () => Get.toNamed(AppRoutes.preferences),
                      onCreateChat: () async {
                        final chatController = Get.find<ChatController>();
                        await chatController.startNewChat();
                      },
                      onMenuStateChanged: (_) {},
                      onOpenConversation: (id) async {
                        final chatController = Get.find<ChatController>();
                        await chatController.loadConversation(id);
                        navController.showChat();
                        final state = _headerKey.currentState;
                        try {
                          // Close header menu if open
                          // ignore: invalid_use_of_protected_member
                          // Use dynamic call to access method
                          // This is safe because we control the widget
                          // and added the method in its State
                          // ignore: avoid_dynamic_calls
                          (state as dynamic).closeMenuExternal();
                        } catch (_) {}
                      },
                    ),

                  // Search bar below header, above conversations list (only when showing list)
                  if (!navController.showEditProfile.value &&
                      !navController.showChatView.value)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Obx(
                        () => TextField(
                          controller: _chatSearchController,
                          decoration: InputDecoration(
                            hintText: TranslationService.translate('search_chats'),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.black87,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.black87,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (q) async {
                            final List<ConversationLocal> convs =
                                await ChatService.getConversations();
                            final String query = q.trim().toLowerCase();
                            ConversationLocal? match;
                            for (final c in convs) {
                              final title = (c.title ?? '').toLowerCase();
                              if (title.contains(query)) {
                                match = c;
                                break;
                              }
                            }
                            if (match != null) {
                              final chatController = Get.find<ChatController>();
                              await chatController.loadConversation(match.id);
                              navController.showChat();
                              final state = _headerKey.currentState;
                              try {
                                (state as dynamic).closeMenuExternal();
                              } catch (_) {}
                            }
                          },
                        ),
                      ),
                    ),

                  // Quick actions below search (Documents / Analytics / Sync)
                  if (!navController.showEditProfile.value &&
                      !navController.showChatView.value)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Get.toNamed(AppRoutes.documents),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[600]!
                                        : Colors.black87,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_copy_outlined, color: Theme.of(context).iconTheme.color, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Obx(() => Text(
                                        TranslationService.translate('documents'),
                                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Get.toNamed(AppRoutes.analytics),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[600]!
                                        : Colors.black87,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.analytics_outlined, color: Theme.of(context).iconTheme.color, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Obx(() => Text(
                                        TranslationService.translate('analytics'),
                                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main content
                  Expanded(
                    child: Stack(
                      children: [
                        Obx(() {
                          // Use ValueKey to prevent unnecessary rebuilds
                          if (navController.showEditProfile.value) {
                            return const EditProfilePage(key: ValueKey('edit_profile'));
                          } else if (navController.showChatView.value) {
                            return const ChatPage(key: ValueKey('chat'));
                          } else {
                            return const ConversationsList(key: ValueKey('conversations'));
                          }
                        }),
                        // Sync button in bottom right corner
                        if (!navController.showEditProfile.value &&
                            !navController.showChatView.value)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: _buildSyncButton(context),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Removed transparent overlay that intercepted taps over the dropdown

              // Loading overlay
              Obx(() {
                if (navController.showLoadingOverlay.value) {
                  return Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                navController.loadingMessage.value,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSyncButton(BuildContext context) {
    final RxBool isSyncing = false.obs;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Obx(() {
      final bool syncing = isSyncing.value;
      
      return GestureDetector(
        onTap: syncing ? null : () async {
          // Check if user is logged in
          if (!AuthService.isLoggedIn) {
            Get.snackbar(
              TranslationService.translate('error'),
              TranslationService.translate('must_be_logged_in_to_sync'),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
            );
            return;
          }

          isSyncing.value = true;
          
          try {
            // Show loading dialog
            Get.dialog(
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        TranslationService.translate('syncing_data'),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              barrierDismissible: false,
            );

            // Perform sync
            await AuthService.manualSync();
            
            // Close loading dialog
            Get.back();
            
            // Reload conversations list
            // The conversations list will automatically reload when sync completes
            // No need to manually reload it

            // Show success message
            Get.snackbar(
              TranslationService.translate('success'),
              TranslationService.translate('sync_completed_successfully'),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green[100],
              colorText: Colors.green[800],
              duration: const Duration(seconds: 2),
            );
          } catch (e) {
            // Close loading dialog if still open
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            
            // Show error message
            Get.snackbar(
              TranslationService.translate('error'),
              TranslationService.translate('sync_failed'),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              duration: const Duration(seconds: 3),
            );
          } finally {
            isSyncing.value = false;
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: syncing
                ? (isDark ? Colors.grey[800] : Colors.grey[300])
                : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[600]! : Colors.black87,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: syncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.sync,
                    color: Theme.of(context).iconTheme.color,
                    size: 24,
                  ),
          ),
        ),
      );
    });
  }
}
