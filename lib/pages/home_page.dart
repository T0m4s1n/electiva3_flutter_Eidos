import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/app_controller.dart';
import '../widgets/animated_header.dart';
import '../widgets/loading_screen.dart';
import '../widgets/conversations_list.dart';
import 'auth_page.dart';
import 'edit_profile_page.dart';
import 'chat_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      // Show loading screen if initial loading
      if (appController.isInitialLoading.value) {
        return const LoadingScreen(
          message: 'Welcome to Eidos',
          duration: Duration(seconds: 2),
        );
      }

      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Custom animated header - only show when not in auth view or edit profile
              if (!navController.showAuthView.value &&
                  !navController.showEditProfile.value)
                AnimatedHeader(
                  isLoggedIn: authController.isLoggedIn.value,
                  userName: authController.userName.value,
                  userEmail: authController.userEmail.value,
                  userAvatarUrl: authController.userAvatarUrl.value.isNotEmpty
                      ? authController.userAvatarUrl.value
                      : null,
                  onLogin: () => navController.showAuth(),
                  onLogout: () => authController.signOut(),
                  onEditProfile: () => navController.showEditProfileView(),
                  onCreateChat: () => navController.showChat(),
                ),

              // Main content
              Expanded(
                child: Obx(() {
                  if (navController.showAuthView.value) {
                    return const AuthPage();
                  } else if (navController.showEditProfile.value) {
                    return const EditProfilePage();
                  } else if (navController.showChatView.value) {
                    return const ChatPage();
                  } else {
                    return const ConversationsList();
                  }
                }),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                navController.loadingMessage.value,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
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
