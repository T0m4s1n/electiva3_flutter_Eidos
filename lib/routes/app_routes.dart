import 'package:get/get.dart';
import '../pages/home_page.dart';
import '../pages/auth_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/chat_page.dart';
import '../pages/loading_page.dart';
import '../bindings/app_bindings.dart';

class AppRoutes {
  static const String home = '/';
  static const String auth = '/auth';
  static const String editProfile = '/edit-profile';
  static const String chat = '/chat';
  static const String loading = '/loading';

  static List<GetPage> routes = [
    GetPage(name: home, page: () => const HomePage(), binding: HomeBinding()),
    GetPage(name: auth, page: () => const AuthPage(), binding: AuthBinding()),
    GetPage(
      name: editProfile,
      page: () => const EditProfilePage(),
      binding: AuthBinding(),
    ),
    GetPage(name: chat, page: () => const ChatPage()),
    GetPage(name: loading, page: () => const LoadingPage()),
  ];
}
