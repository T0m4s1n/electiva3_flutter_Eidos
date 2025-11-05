import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'routes/app_routes.dart';  
import 'bindings/app_bindings.dart';
import 'config/app_theme.dart';
import 'controllers/theme_controller.dart';
import 'services/hive_storage_service.dart';
import 'services/reminder_service.dart';
import 'services/translation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive storage
    await HiveStorageService.init();
    debugPrint('Hive storage initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Hive storage: $e');
    // Continue with app initialization even if Hive fails
  }

  try {
    // Initialize Translation service
    await TranslationService.init();
    debugPrint('Translation service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Translation service: $e');
    // Continue with app initialization even if Translation service fails
  }

  try {
    // Initialize Reminder service
    await ReminderService.init();
    debugPrint('Reminder service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Reminder service: $e');
    // Continue with app initialization even if Reminder service fails
  }

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
    // If .env fails, we cannot proceed without credentials
    throw Exception(
      'Failed to load environment variables. Please check your .env file.',
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.put(ThemeController());

    return Obx(
      () => GetMaterialApp(
        title: TranslationService.translate('app_name'),
        debugShowCheckedModeBanner: false,
        initialBinding: InitialBinding(),
        initialRoute: AppRoutes.home,
        getPages: AppRoutes.routes,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode.value,
      ),
    );
  }
}
