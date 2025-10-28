import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/preferences_controller.dart';
import '../controllers/theme_controller.dart';

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
        child: Padding(
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
                  Text(
                    'Preferencias',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
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
                      _buildSectionHeader(
                        context,
                        'Preferencias de la Aplicación',
                        Icons.settings_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildAppPreferencesCard(
                        context,
                        preferencesController,
                        themeController,
                      ),

                      const SizedBox(height: 32),

                      // Chat Preferences Section
                      _buildSectionHeader(
                        context,
                        'Preferencias del Chat',
                        Icons.chat_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildChatPreferencesCard(context, preferencesController),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
          Text(
            'Tema de la Aplicación',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cambia entre modo claro y oscuro',
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
                    Text(
                      themeController.isDarkMode.value
                          ? 'Modo Oscuro'
                          : 'Modo Claro',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
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
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
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
          Text(
            'Personalidad de la IA',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige cómo quieres que responda la IA',
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
            () => DropdownButtonFormField<AIPersonality>(
              value: preferencesController.aiPersonality.value,
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
}
