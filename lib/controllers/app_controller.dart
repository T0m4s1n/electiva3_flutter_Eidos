import 'package:get/get.dart';

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
    // Dark mode is now managed locally in app state
  }

  // Language management
  void changeLanguage(String language) {
    currentLanguage.value = language;
    // Language is now managed locally in app state
  }

  // Notifications management
  void toggleNotifications() {
    notificationsEnabled.value = !notificationsEnabled.value;
    // Notifications are now managed locally in app state
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
