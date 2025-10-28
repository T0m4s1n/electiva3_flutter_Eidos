import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/app_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/theme_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Register controllers as singletons
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<NavigationController>(NavigationController(), permanent: true);
    Get.put<AppController>(AppController(), permanent: true);
    Get.put<ChatController>(ChatController(), permanent: true);
  }
}

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure AuthController is available for auth-related pages
    Get.lazyPut<AuthController>(() => AuthController());
  }
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure NavigationController and ChatController are available for home page
    Get.lazyPut<NavigationController>(() => NavigationController());
    Get.lazyPut<ChatController>(() => ChatController());
  }
}

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure ChatController is available for chat page
    Get.lazyPut<ChatController>(() => ChatController());
  }
}
