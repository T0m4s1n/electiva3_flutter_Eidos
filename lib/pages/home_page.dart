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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isHeaderMenuOpen = false;

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
        return const LoadingScreen(
          message: 'Welcome to Eidos',
          duration: Duration(milliseconds: 300),
        );
      }

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Custom animated header - only show when not in edit profile
                  if (!navController.showEditProfile.value)
                    AnimatedHeader(
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
                      onMenuStateChanged: (isOpen) {
                        setState(() {
                          _isHeaderMenuOpen = isOpen;
                        });
                      },
                    ),

                  // Main content
                  Expanded(
                    child: Obx(() {
                      if (navController.showEditProfile.value) {
                        return const EditProfilePage();
                      } else if (navController.showChatView.value) {
                        return const ChatPage();
                      } else {
                        return const ConversationsList();
                      }
                    }),
                  ),
                ],
              ),

              // Transparent overlay to close header menu when tapping outside
              // Position it below the header (starting from ~80px down)
              if (_isHeaderMenuOpen)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isHeaderMenuOpen = false;
                      });
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

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
}
