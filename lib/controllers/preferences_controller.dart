import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AIPersonality {
  precise(
    'Preciso',
    'Eres un asistente de IA preciso y directo. Proporcionas respuestas concisas, basadas en hechos y datos específicos.',
  ),
  creative(
    'Creativo',
    'Eres un asistente de IA creativo e imaginativo. Proporcionas respuestas innovadoras, sugerencias creativas y enfoques únicos.',
  ),
  writer(
    'Redactor',
    'Eres un asistente de IA especializado en redacción. Proporcionas respuestas bien estructuradas, detalladas y con excelente calidad de escritura.',
  );

  const AIPersonality(this.displayName, this.systemPrompt);

  final String displayName;
  final String systemPrompt;
}

class PreferencesController extends GetxController {
  // Observable variables for preferences
  final Rx<AIPersonality> aiPersonality = AIPersonality.precise.obs;
  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  // Load preferences from storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load AI personality
      final String? personalityString = prefs.getString('ai_personality');
      if (personalityString != null) {
        aiPersonality.value = AIPersonality.values.firstWhere(
          (p) => p.name == personalityString,
          orElse: () => AIPersonality.precise,
        );
      }

      // Load theme preference
      final bool? isDark = prefs.getBool('isDarkMode');
      if (isDark != null) {
        isDarkMode.value = isDark;
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  // Save AI personality preference
  Future<void> setAIPersonality(AIPersonality personality) async {
    aiPersonality.value = personality;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_personality', personality.name);
    } catch (e) {
      debugPrint('Error saving AI personality preference: $e');
    }
  }

  // Save theme preference
  Future<void> setThemeMode(bool dark) async {
    isDarkMode.value = dark;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', dark);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  // Get current AI personality system prompt
  String get currentSystemPrompt => aiPersonality.value.systemPrompt;
}
