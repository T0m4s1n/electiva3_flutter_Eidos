import 'package:get/get.dart';
import 'auth_controller.dart';

class AppController extends GetxController {
  // Observable variables for app-wide state
  final RxBool isInitialLoading = true.obs;
  final RxBool isDarkMode = false.obs;
  final RxString currentLanguage = 'English'.obs;
  final RxBool notificationsEnabled = true.obs;
  final RxList<Map<String, dynamic>> recentChats = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _initializeApp();
  }

  void _initializeApp() {
    // Simulate initial loading
    Future.delayed(const Duration(milliseconds: 500), () {
      isInitialLoading.value = false;
    });
  }

  // Theme management
  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    // You can also update the user profile here
    Get.find<AuthController>().updateUserProfile(
      darkModeEnabled: isDarkMode.value,
    );
  }

  // Language management
  void changeLanguage(String language) {
    currentLanguage.value = language;
    // You can also update the user profile here
    Get.find<AuthController>().updateUserProfile(language: language);
  }

  // Notifications management
  void toggleNotifications() {
    notificationsEnabled.value = !notificationsEnabled.value;
    // You can also update the user profile here
    Get.find<AuthController>().updateUserProfile(
      notificationsEnabled: notificationsEnabled.value,
    );
  }

  // Chat management
  void addRecentChat(Map<String, dynamic> chat) {
    recentChats.insert(0, chat);
    // Keep only the last 10 chats
    if (recentChats.length > 10) {
      recentChats.removeLast();
    }
  }

  void removeRecentChat(String chatId) {
    recentChats.removeWhere((chat) => chat['id'] == chatId);
  }

  void clearRecentChats() {
    recentChats.clear();
  }

  // App state management
  void resetAppState() {
    isInitialLoading.value = false;
    isDarkMode.value = false;
    currentLanguage.value = 'English';
    notificationsEnabled.value = true;
    recentChats.clear();
  }
}
