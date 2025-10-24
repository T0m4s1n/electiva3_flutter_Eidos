import 'package:get/get.dart';

class NavigationController extends GetxController {
  // Observable variables for navigation state
  final RxBool showChatView = false.obs;
  final RxBool showAuthView = false.obs;
  final RxBool showEditProfile = false.obs;
  final RxBool isLoginView = true.obs;
  final RxBool showLoadingOverlay = false.obs;
  final RxString loadingMessage = ''.obs;

  // Navigation methods
  void showAuth() {
    showAuthView.value = true;
    isLoginView.value = true;
  }

  void hideAuth() {
    showAuthView.value = false;
  }

  void toggleAuthMode() {
    isLoginView.value = !isLoginView.value;
  }

  void showEditProfileView() {
    showEditProfile.value = true;
  }

  void hideEditProfileView() {
    showEditProfile.value = false;
  }

  void showChat() {
    showChatView.value = true;
  }

  void hideChat() {
    showChatView.value = false;
  }

  void showLoading(String message) {
    loadingMessage.value = message;
    showLoadingOverlay.value = true;
  }

  void hideLoading() {
    showLoadingOverlay.value = false;
    loadingMessage.value = '';
  }

  void resetAllViews() {
    showChatView.value = false;
    showAuthView.value = false;
    showEditProfile.value = false;
    isLoginView.value = true;
    showLoadingOverlay.value = false;
    loadingMessage.value = '';
  }

  // Get current view state
  String get currentView {
    if (showAuthView.value) return 'auth';
    if (showEditProfile.value) return 'edit_profile';
    if (showChatView.value) return 'chat';
    return 'home';
  }
}
