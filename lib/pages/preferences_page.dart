import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/preferences_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/chat_rule.dart';
import '../routes/app_routes.dart';
import '../widgets/animated_icon_background.dart';
import '../services/translation_service.dart';
import '../services/auth_service.dart';
import '../services/passkey_service.dart';
import '../widgets/theme_change_loader.dart';
import '../controllers/auth_controller.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PreferencesController preferencesController =
        Get.find<PreferencesController>();
    final ThemeController themeController = Get.find<ThemeController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Theme change loader overlay (fullscreen)
            Positioned.fill(
              child: ThemeChangeLoader(),
            ),
            const Positioned.fill(child: ChatIconBackground()),
            Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[600]!
                              : Colors.black87,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).iconTheme.color,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Obx(
                      () => Text(
                        TranslationService.translate('preferences'),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Preferences sections
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Preferences Section
                      Obx(
                        () => _buildSectionHeader(
                        context,
                          TranslationService.translate('app_preferences'),
                        Icons.settings_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAppPreferencesCard(
                        context,
                        preferencesController,
                        themeController,
                      ),
                      const SizedBox(height: 16),
                      _buildLanguageCard(context),

                      const SizedBox(height: 32),

                      // Chat Preferences Section
                      Obx(
                        () => _buildSectionHeader(
                        context,
                          TranslationService.translate('chat_preferences'),
                        Icons.chat_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChatPreferencesCard(context, preferencesController),

                      const SizedBox(height: 32),

                      // Chat Rules Section
                      Obx(
                        () => _buildSectionHeader(
                        context,
                          TranslationService.translate('chat_rules'),
                        Icons.rule_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChatRulesCard(context, preferencesController),

                      const SizedBox(height: 32),

                      // More Section
                      Obx(
                        () => _buildSectionHeader(
                          context,
                          TranslationService.translate('more'),
                          Icons.more_horiz,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMoreCard(context, preferencesController),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreCard(BuildContext context, PreferencesController preferencesController) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.black87,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDocumentCreationConfig(context, preferencesController),
          const Divider(height: 24),
          Obx(
            () => _buildNavTile(
              context,
              icon: Icons.analytics_outlined,
              title: TranslationService.translate('analytics'),
              subtitle: 'View your analytics',
              route: AppRoutes.analytics,
            ),
          ),
          const Divider(height: 24),
          _buildNavTile(
            context,
            icon: Icons.tune_outlined,
            title: 'Advanced Settings',
            subtitle: 'Model options and behavior controls',
            route: AppRoutes.advancedSettings,
          ),
          const Divider(height: 24),
          _buildNavTile(
            context,
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Choose what alerts you receive',
            route: AppRoutes.notifications,
          ),
          const Divider(height: 24),
          _buildNavTile(
            context,
            icon: Icons.support_agent,
            title: 'Feedback & Support',
            subtitle: 'Report issues or request features',
            route: AppRoutes.feedback,
          ),
          const Divider(height: 24),
          _buildSyncButton(context),
          const Divider(height: 24),
          _buildPasskeySection(context),
        ],
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RxBool isSyncing = false.obs;
    
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: syncing 
                ? (isDark ? Colors.grey[800] : Colors.grey[200])
                : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[600]! : Colors.black87,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.black87,
                  ),
                ),
                child: syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.sync,
                        color: Theme.of(context).iconTheme.color,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.translate('sync_with_cloud'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      syncing
                          ? TranslationService.translate('syncing_data')
                          : TranslationService.translate('sync_all_data_with_cloud'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (!syncing)
                Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPasskeySection(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AuthController authController = Get.find<AuthController>();
    final RxBool hasPasskeys = false.obs;
    final RxBool isLoading = false.obs;
    
    // Check if user has passkeys
    Future.microtask(() async {
      if (AuthService.isLoggedIn) {
        hasPasskeys.value = await PasskeyService.hasPasskeys(AuthService.currentUser!.id);
      }
    });
    
    return Obx(() {
      if (!AuthService.isLoggedIn) {
        return const SizedBox.shrink();
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fingerprint,
                color: isDark ? Colors.blue[300] : Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Passkey Authentication',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasPasskeys.value
                ? 'You have a passkey registered. You can sign in with biometrics.'
                : 'Register a passkey to sign in securely with your fingerprint or face.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (hasPasskeys.value)
            GestureDetector(
              onTap: isLoading.value ? null : () async {
                // Show dialog to manage passkeys
                _showPasskeyManagementDialog(context);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.black87,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts,
                      color: isDark ? Colors.blue[300] : Colors.blue[600],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manage Passkeys',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: isLoading.value ? null : () async {
                isLoading.value = true;
                try {
                  // Check if device supports biometrics
                  final isSupported = await PasskeyService.isDeviceSupported();
                  if (!isSupported) {
                    Get.snackbar(
                      'Not Supported',
                      'Your device does not support biometric authentication.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red[100],
                      colorText: Colors.red[800],
                    );
                    return;
                  }
                  
                  // Show dialog to enter password for passkey registration
                  _showRegisterPasskeyDialog(context, authController);
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to check device support: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red[100],
                    colorText: Colors.red[800],
                  );
                } finally {
                  isLoading.value = false;
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.black87,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: isDark ? Colors.blue[300] : Colors.blue[600],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Register Passkey',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  void _showRegisterPasskeyDialog(BuildContext context, AuthController authController) {
    final passwordController = TextEditingController();
    
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register Passkey',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your password to register a passkey. This will allow you to sign in with biometrics.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (passwordController.text.isEmpty) {
                        Get.snackbar(
                          'Error',
                          'Please enter your password',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red[100],
                          colorText: Colors.red[800],
                        );
                        return;
                      }
                      
                      Get.back();
                      
                      try {
                        await authController.registerPasskey(
                          password: passwordController.text,
                        );
                        
                        Get.snackbar(
                          'Success',
                          'Passkey registered successfully!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green[100],
                          colorText: Colors.green[800],
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to register passkey: ${e.toString()}',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red[100],
                          colorText: Colors.red[800],
                        );
                      }
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasskeyManagementDialog(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: authController.getUserPasskeys(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: const CircularProgressIndicator(),
              );
            }
            
            final passkeys = snapshot.data ?? [];
            
            return Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage Passkeys',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (passkeys.isEmpty)
                    Text(
                      'No passkeys registered',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: passkeys.length,
                        itemBuilder: (context, index) {
                          final passkey = passkeys[index];
                          return ListTile(
                            leading: const Icon(Icons.fingerprint),
                            title: Text(
                              passkey['device_name'] ?? 'Unknown Device',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              passkey['device_type'] ?? 'Unknown',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await authController.deletePasskey(
                                    passkey['passkey_id'] as String,
                                  );
                                  Get.back();
                                  Get.snackbar(
                                    'Success',
                                    'Passkey deleted successfully',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.green[100],
                                    colorText: Colors.green[800],
                                  );
                                } catch (e) {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to delete passkey: ${e.toString()}',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red[100],
                                    colorText: Colors.red[800],
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Get.toNamed(route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.black87,
              ),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).iconTheme.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAppPreferencesCard(
    BuildContext context,
    PreferencesController preferencesController,
    ThemeController themeController,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.black87,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Text(
              TranslationService.translate('app_theme'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              TranslationService.translate('switch_theme'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      themeController.isDarkMode.value
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Text(
                      themeController.isDarkMode.value
                            ? TranslationService.translate('dark_mode')
                            : TranslationService.translate('light_mode'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: themeController.isDarkMode.value,
                  onChanged: (value) {
                    themeController.setThemeMode(value);
                    preferencesController.setThemeMode(value);
                  },
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.black87,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.language,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Obx(
                () => Text(
                  TranslationService.translate('language'),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              TranslationService.translate('select_app_language'),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => DropdownButtonFormField<AppLanguage>(
              initialValue: TranslationService.currentLanguageObs.value,
              decoration: InputDecoration(
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
              ),
              dropdownColor: Theme.of(context).cardTheme.color,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: TranslationService.availableLanguages.map((language) {
                return DropdownMenuItem<AppLanguage>(
                  value: language,
                  child: Text(language.displayName),
                );
              }).toList(),
              onChanged: (AppLanguage? newValue) async {
                if (newValue != null) {
                  // Don't await to prevent blocking the UI
                  TranslationService.setLanguage(newValue);
                  // Show confirmation after a delay to prevent UI jank
                  Future.delayed(const Duration(milliseconds: 300), () {
                    Get.snackbar(
                      TranslationService.translate('language_changed'),
                      '${TranslationService.translate('app_language_changed_to')} ${newValue.displayName}',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreferencesCard(
    BuildContext context,
    PreferencesController preferencesController,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.black87,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model selection
          Text(
            'AI Model',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the model to use (visual selection only)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => DropdownButtonFormField<String>(
              initialValue: preferencesController.model.value,
              decoration: InputDecoration(
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
              ),
              dropdownColor: Theme.of(context).cardTheme.color,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: const [
                // OpenAI GPT Models (Functional)
                DropdownMenuItem<String>(
                  value: 'gpt-4o-mini',
                  child: Text('GPT-4o Mini (Current)'),
                ),
                DropdownMenuItem<String>(
                  value: 'gpt-4o',
                  child: Text('GPT-4o'),
                ),
                DropdownMenuItem<String>(
                  value: 'gpt-4-turbo',
                  child: Text('GPT-4 Turbo'),
                ),
                DropdownMenuItem<String>(
                  value: 'gpt-4',
                  child: Text('GPT-4'),
                ),
                DropdownMenuItem<String>(
                  value: 'gpt-3.5-turbo',
                  child: Text('GPT-3.5 Turbo'),
                ),
                DropdownMenuItem<String>(
                  value: 'o1-preview',
                  child: Text('O1 Preview'),
                ),
                DropdownMenuItem<String>(
                  value: 'o1-mini',
                  child: Text('O1 Mini'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  preferencesController.setModel(value);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          Obx(
            () => Text(
              TranslationService.translate('ai_personality'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              TranslationService.translate('select_ai_personality'),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => DropdownButtonFormField<AIPersonality>(
              initialValue: preferencesController.aiPersonality.value,
              decoration: InputDecoration(
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
              ),
              dropdownColor: Theme.of(context).cardTheme.color,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: AIPersonality.values.map((personality) {
                return DropdownMenuItem<AIPersonality>(
                  value: personality,
                  child: Text(personality.displayName),
                );
              }).toList(),
              onChanged: (AIPersonality? newValue) {
                if (newValue != null) {
                  preferencesController.setAIPersonality(newValue);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          // Personality description
          Obx(
            () => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[600]!
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                preferencesController.aiPersonality.value.systemPrompt,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRulesCard(
    BuildContext context,
    PreferencesController preferencesController,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.black87,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Rules',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddRuleDialog(context, preferencesController),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]!
                          : Colors.black87,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Define what the AI should and should not do',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (preferencesController.chatRules.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  'No rules defined. Tap the + button to add a rule.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Positive rules
                if (preferencesController.positiveRules.isNotEmpty) ...[
                  _buildRulesSection(
                    context,
                    'Positive Rules (Should do)',
                    preferencesController.positiveRules,
                    Colors.green,
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 12),
                ],
                // Negative rules
                if (preferencesController.negativeRules.isNotEmpty) ...[
                  _buildRulesSection(
                    context,
                    'Negative Rules (Should not do)',
                    preferencesController.negativeRules,
                    Colors.red,
                    Icons.cancel_outlined,
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRulesSection(
    BuildContext context,
    String title,
    List<ChatRule> rules,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rules.map((rule) => _buildRuleItem(context, rule)),
      ],
    );
  }

  Widget _buildRuleItem(BuildContext context, ChatRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rule.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showEditRuleDialog(context, rule),
                child: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showDeleteRuleDialog(context, rule),
                child: Icon(Icons.delete_outline, color: Colors.red, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog(
    BuildContext context,
    PreferencesController controller,
  ) {
    final TextEditingController textController = TextEditingController();
    bool isPositive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          title: Obx(
            () => Text(
              '${TranslationService.translate('add')} ${TranslationService.translate('chat_rules').toLowerCase().replaceAll('chat rules', 'Rule')}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Rule text',
                  labelStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        'Should do',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                      value: true,
                      groupValue: isPositive,
                      onChanged: (value) => setState(() => isPositive = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        'Should not do',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                      value: false,
                      groupValue: isPositive,
                      onChanged: (value) => setState(() => isPositive = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Obx(
              () => TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                  TranslationService.translate('cancel'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ),
            Obx(
              () => ElevatedButton(
              onPressed: () async {
                if (textController.text.trim().isNotEmpty) {
                  await controller.addChatRule(
                    textController.text.trim(),
                    isPositive,
                  );
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                  TranslationService.translate('add'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black87
                      : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, ChatRule rule) {
    final TextEditingController textController = TextEditingController(
      text: rule.text,
    );
    bool isPositive = rule.isPositive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          title: Obx(
            () => Text(
              '${TranslationService.translate('edit')} ${TranslationService.translate('chat_rules').toLowerCase().replaceAll('chat rules', 'Rule')}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Rule text',
                  labelStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        'Should do',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                      value: true,
                      groupValue: isPositive,
                      onChanged: (value) => setState(() => isPositive = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(
                        'Should not do',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      ),
                      value: false,
                      groupValue: isPositive,
                      onChanged: (value) => setState(() => isPositive = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Obx(
              () => TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                  TranslationService.translate('cancel'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ),
            Obx(
              () => ElevatedButton(
              onPressed: () async {
                if (textController.text.trim().isNotEmpty) {
                  await Get.find<PreferencesController>().updateChatRule(
                    rule.id,
                    textController.text.trim(),
                    isPositive,
                  );
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                  TranslationService.translate('save'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black87
                      : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteRuleDialog(BuildContext context, ChatRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
          title: Obx(
            () => Text(
              '${TranslationService.translate('delete')} ${TranslationService.translate('chat_rules').toLowerCase().replaceAll('chat rules', 'Rule')}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
              ),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this rule?',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Obx(
            () => TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
                TranslationService.translate('cancel'),
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ),
          Obx(
            () => ElevatedButton(
            onPressed: () async {
              await Get.find<PreferencesController>().deleteChatRule(rule.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
                TranslationService.translate('delete'),
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCreationConfig(
    BuildContext context,
    PreferencesController preferencesController,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder_copy_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                TranslationService.translate('documents'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Configure document creation settings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        
        // Auto-save documents
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-save Documents',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automatically save documents as you edit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: preferencesController.autoSaveDocuments.value,
                onChanged: (value) {
                  preferencesController.setAutoSaveDocuments(value);
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Auto-create versions
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-create Versions',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create version history when saving',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: preferencesController.autoCreateVersions.value,
                onChanged: (value) {
                  preferencesController.setAutoCreateVersions(value);
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Default document format
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Document Format',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => DropdownButtonFormField<String>(
                value: preferencesController.defaultDocumentFormat.value,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[600]! : Colors.black87,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[600]! : Colors.black87,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: Theme.of(context).cardTheme.color,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'markdown',
                    child: Text('Markdown'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'plain',
                    child: Text('Plain Text'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    preferencesController.setDefaultDocumentFormat(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
