import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_rule.dart';
import '../services/hive_storage_service.dart';
import 'package:uuid/uuid.dart';

enum AIPersonality {
  precise(
    'Precise',
    'You are a precise and direct AI assistant. You provide concise responses based on facts and specific data.',
  ),
  creative(
    'Creative',
    'You are a creative and imaginative AI assistant. You provide innovative responses, creative suggestions, and unique approaches.',
  ),
  writer(
    'Writer',
    'You are an AI assistant specialized in writing. You provide well-structured, detailed responses with excellent writing quality.',
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
  final RxString model = 'gpt-4o-mini'.obs;
  
  // Document creation preferences
  final RxBool autoSaveDocuments = true.obs;
  final RxBool autoCreateVersions = true.obs;
  final RxString defaultDocumentFormat = 'markdown'.obs;

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

      // Load model preference
      model.value = HiveStorageService.loadModel();

      // Load chat rules
      chatRules.value = HiveStorageService.getAllChatRules();

      // Load document creation preferences
      autoSaveDocuments.value = HiveStorageService.loadAutoSaveDocuments();
      autoCreateVersions.value = HiveStorageService.loadAutoCreateVersions();
      defaultDocumentFormat.value = HiveStorageService.loadDefaultDocumentFormat();

      debugPrint('Preferences loaded successfully');
      debugPrint('AI Personality: ${aiPersonality.value.displayName}');
      debugPrint('Theme Mode: ${isDarkMode.value ? 'Dark' : 'Light'}');
      debugPrint('Model: ${model.value}');
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

  // Save model preference
  Future<void> setModel(String newModel) async {
    try {
      model.value = newModel;
      await HiveStorageService.saveModel(newModel);
      debugPrint('Model updated: $newModel');
    } catch (e) {
      debugPrint('Error saving model preference: $e');
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

  // ========== DOCUMENT CREATION PREFERENCES ==========

  /// Save auto-save documents preference
  Future<void> setAutoSaveDocuments(bool autoSave) async {
    try {
      autoSaveDocuments.value = autoSave;
      await HiveStorageService.saveAutoSaveDocuments(autoSave);
      debugPrint('Auto-save documents updated: $autoSave');
    } catch (e) {
      debugPrint('Error saving auto-save documents preference: $e');
    }
  }

  /// Save auto-create versions preference
  Future<void> setAutoCreateVersions(bool autoCreate) async {
    try {
      autoCreateVersions.value = autoCreate;
      await HiveStorageService.saveAutoCreateVersions(autoCreate);
      debugPrint('Auto-create versions updated: $autoCreate');
    } catch (e) {
      debugPrint('Error saving auto-create versions preference: $e');
    }
  }

  /// Save default document format preference
  Future<void> setDefaultDocumentFormat(String format) async {
    try {
      defaultDocumentFormat.value = format;
      await HiveStorageService.saveDefaultDocumentFormat(format);
      debugPrint('Default document format updated: $format');
    } catch (e) {
      debugPrint('Error saving default document format: $e');
    }
  }
}
