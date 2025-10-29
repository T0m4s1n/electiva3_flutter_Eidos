import 'package:get/get.dart';
import '../pages/home_page.dart';
import '../pages/auth_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/chat_page.dart';
import '../pages/loading_page.dart';
import '../pages/preferences_page.dart';
import '../pages/chat_archive_page.dart';
import '../pages/documents_manager_page.dart';
import '../pages/analytics_page.dart';
import '../pages/advanced_settings_page.dart';
import '../pages/notifications_page.dart';
import '../pages/feedback_support_page.dart';
import '../bindings/app_bindings.dart';

class AppRoutes {
  static const String home = '/';
  static const String auth = '/auth';
  static const String editProfile = '/edit-profile';
  static const String chat = '/chat';
  static const String loading = '/loading';
  static const String preferences = '/preferences';
  static const String archive = '/archive';
  static const String documents = '/documents';
  static const String analytics = '/analytics';
  static const String advancedSettings = '/advanced-settings';
  static const String notifications = '/notifications';
  static const String feedback = '/feedback';

  static List<GetPage> routes = [
    GetPage(name: home, page: () => const HomePage(), binding: HomeBinding()),
    GetPage(name: auth, page: () => const AuthPage(), binding: AuthBinding()),
    GetPage(
      name: editProfile,
      page: () => const EditProfilePage(),
      binding: AuthBinding(),
    ),
    GetPage(name: chat, page: () => const ChatPage(), binding: ChatBinding()),
    GetPage(name: loading, page: () => const LoadingPage()),
    GetPage(
      name: preferences,
      page: () => const PreferencesPage(),
      binding: PreferencesBinding(),
    ),
    GetPage(name: archive, page: () => const ChatArchivePage()),
    GetPage(name: documents, page: () => const DocumentsManagerPage()),
    GetPage(name: analytics, page: () => const AnalyticsPage()),
    GetPage(name: advancedSettings, page: () => const AdvancedSettingsPage()),
    GetPage(name: notifications, page: () => const NotificationsPage()),
    GetPage(name: feedback, page: () => const FeedbackSupportPage()),
  ];
}
