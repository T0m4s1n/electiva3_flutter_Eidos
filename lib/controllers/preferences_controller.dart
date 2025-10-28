import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_rule.dart';
import '../services/hive_storage_service.dart';
import 'package:uuid/uuid.dart';

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
  final RxList<ChatRule> chatRules = <ChatRule>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  // Load preferences from Hive storage
  Future<void> _loadPreferences() async {
    try {
      // Load AI personality
      aiPersonality.value = HiveStorageService.loadAIPersonality();

      // Load theme preference
      isDarkMode.value = HiveStorageService.loadThemeMode();

      // Load chat rules
      chatRules.value = HiveStorageService.getAllChatRules();

      debugPrint('Preferences loaded successfully');
      debugPrint('AI Personality: ${aiPersonality.value.displayName}');
      debugPrint('Theme Mode: ${isDarkMode.value ? 'Dark' : 'Light'}');
      debugPrint('Chat Rules loaded: ${chatRules.length}');

      // Log each rule for debugging
      for (int i = 0; i < chatRules.length; i++) {
        final rule = chatRules[i];
        debugPrint(
          'Rule $i: ${rule.text} (${rule.isPositive ? 'positive' : 'negative'})',
        );
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  // Save AI personality preference
  Future<void> setAIPersonality(AIPersonality personality) async {
    try {
      aiPersonality.value = personality;
      await HiveStorageService.saveAIPersonality(personality);
      debugPrint('AI personality updated: ${personality.displayName}');
    } catch (e) {
      debugPrint('Error saving AI personality preference: $e');
    }
  }

  // Save theme preference
  Future<void> setThemeMode(bool dark) async {
    try {
      isDarkMode.value = dark;
      await HiveStorageService.saveThemeMode(dark);
      debugPrint('Theme mode updated: ${dark ? 'Dark' : 'Light'}');
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  // ========== CHAT RULES METHODS ==========

  /// Add a new chat rule
  Future<void> addChatRule(String text, bool isPositive) async {
    try {
      final String id = const Uuid().v4();
      final DateTime now = DateTime.now();

      final ChatRule newRule = ChatRule(
        id: id,
        text: text.trim(),
        isPositive: isPositive,
        createdAt: now,
        updatedAt: now,
      );

      await HiveStorageService.addChatRule(newRule);
      chatRules.add(newRule);

      debugPrint('Chat rule added: ${newRule.text}');
    } catch (e) {
      debugPrint('Error adding chat rule: $e');
      rethrow;
    }
  }

  /// Update an existing chat rule
  Future<void> updateChatRule(
    String ruleId,
    String text,
    bool isPositive,
  ) async {
    try {
      final ChatRule? existingRule = chatRules.firstWhereOrNull(
        (r) => r.id == ruleId,
      );
      if (existingRule == null) {
        throw Exception('Rule not found');
      }

      final ChatRule updatedRule = existingRule.copyWith(
        text: text.trim(),
        isPositive: isPositive,
        updatedAt: DateTime.now(),
      );

      await HiveStorageService.updateChatRule(updatedRule);

      final int index = chatRules.indexWhere((r) => r.id == ruleId);
      if (index != -1) {
        chatRules[index] = updatedRule;
      }

      debugPrint('Chat rule updated: ${updatedRule.text}');
    } catch (e) {
      debugPrint('Error updating chat rule: $e');
      rethrow;
    }
  }

  /// Delete a chat rule
  Future<void> deleteChatRule(String ruleId) async {
    try {
      await HiveStorageService.deleteChatRule(ruleId);
      chatRules.removeWhere((r) => r.id == ruleId);
      debugPrint('Chat rule deleted: $ruleId');
    } catch (e) {
      debugPrint('Error deleting chat rule: $e');
      rethrow;
    }
  }

  /// Get positive rules (things AI should do)
  List<ChatRule> get positiveRules =>
      chatRules.where((r) => r.isPositive).toList();

  /// Get negative rules (things AI should not do)
  List<ChatRule> get negativeRules =>
      chatRules.where((r) => !r.isPositive).toList();

  /// Clear all chat rules
  Future<void> clearAllChatRules() async {
    try {
      await HiveStorageService.clearAllChatRules();
      chatRules.clear();
      debugPrint('All chat rules cleared');
    } catch (e) {
      debugPrint('Error clearing chat rules: $e');
      rethrow;
    }
  }

  /// Get current AI personality system prompt with rules
  String get currentSystemPrompt {
    String basePrompt = aiPersonality.value.systemPrompt;

    // Get rules directly from Hive to ensure we have the latest data
    String rulesPrompt = HiveStorageService.generateRulesPrompt();

    debugPrint('Base prompt: $basePrompt');
    debugPrint('Rules prompt: $rulesPrompt');
    debugPrint('Total chat rules in controller: ${chatRules.length}');
    debugPrint(
      'Total chat rules in Hive: ${HiveStorageService.getChatRulesCount()}',
    );

    if (rulesPrompt.isNotEmpty) {
      String combinedPrompt = '$basePrompt\n\n$rulesPrompt';
      debugPrint('Combined prompt: $combinedPrompt');
      return combinedPrompt;
    }

    return basePrompt;
  }

  /// Get rules-only prompt for display purposes
  String get rulesOnlyPrompt => HiveStorageService.generateRulesPrompt();
}
