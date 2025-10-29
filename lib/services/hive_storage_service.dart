import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_rule.dart';
import '../controllers/preferences_controller.dart';

class HiveStorageService {
  static const String _preferencesBoxName = 'preferences';
  static const String _chatRulesBoxName = 'chat_rules';

  static Box? _preferencesBox;
  static Box<ChatRule>? _chatRulesBox;

  // Keys for preferences
  static const String _aiPersonalityKey = 'ai_personality';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _modelKey = 'model';

  /// Initialize Hive storage
  static Future<void> init() async {
    try {
      await Hive.initFlutter();

      // Register adapters
      Hive.registerAdapter(ChatRuleAdapter());

      // Open boxes
      _preferencesBox = await Hive.openBox(_preferencesBoxName);
      _chatRulesBox = await Hive.openBox<ChatRule>(_chatRulesBoxName);

      debugPrint('Hive storage initialized successfully');
      debugPrint('Preferences box opened: ${_preferencesBox?.name}');
      debugPrint('Chat rules box opened: ${_chatRulesBox?.name}');
      debugPrint('Chat rules box length: ${_chatRulesBox?.length ?? 0}');
    } catch (e) {
      debugPrint('Error initializing Hive storage: $e');
      rethrow;
    }
  }

  /// Close all boxes
  static Future<void> close() async {
    await _preferencesBox?.close();
    await _chatRulesBox?.close();
  }

  // ========== PREFERENCES METHODS ==========

  /// Save AI personality preference
  static Future<void> saveAIPersonality(AIPersonality personality) async {
    try {
      await _preferencesBox?.put(_aiPersonalityKey, personality.name);
      debugPrint('AI personality saved: ${personality.name}');
    } catch (e) {
      debugPrint('Error saving AI personality: $e');
      rethrow;
    }
  }

  /// Load AI personality preference
  static AIPersonality loadAIPersonality() {
    try {
      final String? personalityString = _preferencesBox?.get(_aiPersonalityKey);
      if (personalityString != null) {
        return AIPersonality.values.firstWhere(
          (p) => p.name == personalityString,
          orElse: () => AIPersonality.precise,
        );
      }
      return AIPersonality.precise;
    } catch (e) {
      debugPrint('Error loading AI personality: $e');
      return AIPersonality.precise;
    }
  }

  /// Save theme preference
  static Future<void> saveThemeMode(bool isDark) async {
    try {
      await _preferencesBox?.put(_isDarkModeKey, isDark);
      debugPrint('Theme mode saved: ${isDark ? 'dark' : 'light'}');
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
      rethrow;
    }
  }

  /// Save preferred AI model
  static Future<void> saveModel(String model) async {
    try {
      await _preferencesBox?.put(_modelKey, model);
      debugPrint('Model saved: $model');
    } catch (e) {
      debugPrint('Error saving model: $e');
      rethrow;
    }
  }

  /// Load preferred AI model
  static String loadModel() {
    try {
      return _preferencesBox?.get(_modelKey, defaultValue: 'gpt-4o-mini')
              as String? ??
          'gpt-4o-mini';
    } catch (e) {
      debugPrint('Error loading model: $e');
      return 'gpt-4o-mini';
    }
  }

  /// Load theme preference
  static bool loadThemeMode() {
    try {
      return _preferencesBox?.get(_isDarkModeKey, defaultValue: false) ?? false;
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      return false;
    }
  }

  // ========== CHAT RULES METHODS ==========

  /// Add a new chat rule
  static Future<void> addChatRule(ChatRule rule) async {
    try {
      if (_chatRulesBox == null) {
        debugPrint('ERROR: Chat rules box is null when trying to add rule!');
        return;
      }

      await _chatRulesBox!.put(rule.id, rule);
      debugPrint('Chat rule added to Hive: ${rule.text}');
      debugPrint('Chat rules box length after add: ${_chatRulesBox!.length}');
    } catch (e) {
      debugPrint('Error adding chat rule: $e');
      rethrow;
    }
  }

  /// Update an existing chat rule
  static Future<void> updateChatRule(ChatRule rule) async {
    try {
      await _chatRulesBox?.put(rule.id, rule);
      debugPrint('Chat rule updated: ${rule.text}');
    } catch (e) {
      debugPrint('Error updating chat rule: $e');
      rethrow;
    }
  }

  /// Delete a chat rule
  static Future<void> deleteChatRule(String ruleId) async {
    try {
      await _chatRulesBox?.delete(ruleId);
      debugPrint('Chat rule deleted: $ruleId');
    } catch (e) {
      debugPrint('Error deleting chat rule: $e');
      rethrow;
    }
  }

  /// Get all chat rules
  static List<ChatRule> getAllChatRules() {
    try {
      if (_chatRulesBox == null) {
        debugPrint('ERROR: Chat rules box is null!');
        return [];
      }

      final List<ChatRule> rules = _chatRulesBox!.values.toList();
      debugPrint(
        'HiveStorageService.getAllChatRules: Retrieved ${rules.length} rules from box',
      );
      return rules;
    } catch (e) {
      debugPrint('Error getting chat rules: $e');
      return [];
    }
  }

  /// Get chat rules by type (positive/negative)
  static List<ChatRule> getChatRulesByType(bool isPositive) {
    try {
      return _chatRulesBox?.values
              .where((rule) => rule.isPositive == isPositive)
              .toList() ??
          [];
    } catch (e) {
      debugPrint('Error getting chat rules by type: $e');
      return [];
    }
  }

  /// Get a specific chat rule by ID
  static ChatRule? getChatRuleById(String ruleId) {
    try {
      return _chatRulesBox?.get(ruleId);
    } catch (e) {
      debugPrint('Error getting chat rule by ID: $e');
      return null;
    }
  }

  /// Clear all chat rules
  static Future<void> clearAllChatRules() async {
    try {
      await _chatRulesBox?.clear();
      debugPrint('All chat rules cleared');
    } catch (e) {
      debugPrint('Error clearing chat rules: $e');
      rethrow;
    }
  }

  /// Get chat rules count
  static int getChatRulesCount() {
    try {
      return _chatRulesBox?.length ?? 0;
    } catch (e) {
      debugPrint('Error getting chat rules count: $e');
      return 0;
    }
  }

  /// Generate formatted rules text for AI system prompt
  static String generateRulesPrompt() {
    try {
      final List<ChatRule> allRules = getAllChatRules();
      debugPrint(
        'HiveStorageService.generateRulesPrompt: Found ${allRules.length} rules',
      );

      if (allRules.isEmpty) {
        debugPrint('No rules found, returning empty string');
        return '';
      }

      final List<ChatRule> positiveRules = allRules
          .where((r) => r.isPositive)
          .toList();
      final List<ChatRule> negativeRules = allRules
          .where((r) => !r.isPositive)
          .toList();

      debugPrint('Positive rules: ${positiveRules.length}');
      debugPrint('Negative rules: ${negativeRules.length}');

      StringBuffer rulesPrompt = StringBuffer();

      if (positiveRules.isNotEmpty) {
        rulesPrompt.writeln('REGLAS QUE DEBES SEGUIR:');
        for (int i = 0; i < positiveRules.length; i++) {
          rulesPrompt.writeln('${i + 1}. ${positiveRules[i].text}');
        }
        rulesPrompt.writeln();
      }

      if (negativeRules.isNotEmpty) {
        rulesPrompt.writeln('REGLAS QUE NO DEBES SEGUIR:');
        for (int i = 0; i < negativeRules.length; i++) {
          rulesPrompt.writeln('${i + 1}. ${negativeRules[i].text}');
        }
        rulesPrompt.writeln();
      }

      String result = rulesPrompt.toString();
      debugPrint('Generated rules prompt: $result');
      return result;
    } catch (e) {
      debugPrint('Error generating rules prompt: $e');
      return '';
    }
  }
}
