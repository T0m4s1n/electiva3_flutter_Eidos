import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import '../controllers/navigation_controller.dart';

class ChatController extends GetxController {
  // Observable variables
  final RxList<MessageLocal> messages = <MessageLocal>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isTyping = false.obs;
  final RxString currentConversationId = ''.obs;
  final RxString conversationTitle = 'New Chat'.obs;
  final RxBool hasMessages = false.obs;

  // Text controller for input
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // OpenAI API key
  String? get openaiKey => dotenv.env['OPENAI_KEY'];

  @override
  void onInit() {
    super.onInit();
    // Don't initialize chat automatically - let it be done manually when needed
  }

  @override
  void onClose() {
    messageController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  /// Initialize a new chat conversation
  Future<void> initializeChat() async {
    try {
      isLoading.value = true;

      // Create a new conversation
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'New Chat',
            model: 'gpt-4o-mini',
          );

      currentConversationId.value = conversation.id;
      conversationTitle.value = conversation.title ?? 'New Chat';
      hasMessages.value = false;

      // Clear any existing messages
      messages.clear();
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _showErrorSnackbar('Error initializing chat');
    } finally {
      isLoading.value = false;
    }
  }

  /// Send a message to the chat
  Future<void> sendMessage() async {
    final String messageText = messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      isLoading.value = true;

      // Clear input
      messageController.clear();

      // Add user message to the chat
      final MessageLocal userMessage = await ChatService.createUserMessage(
        conversationId: currentConversationId.value,
        text: messageText,
      );

      messages.add(userMessage);
      hasMessages.value = true;

      // Update conversation title if it's the first message
      if (messages.length == 1) {
        await _updateConversationTitle(messageText);
      }

      // Scroll to bottom
      _scrollToBottom();

      // Get AI response
      await _getAIResponse(messageText);
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showErrorSnackbar('Error sending message');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get AI response from OpenAI
  Future<void> _getAIResponse(String userMessage) async {
    if (openaiKey == null) {
      _showErrorSnackbar('OpenAI API key not configured');
      return;
    }

    try {
      isTyping.value = true;

      // Limpiar mensajes de error del sistema antes de enviar
      await ChatService.clearSystemErrorMessages(currentConversationId.value);

      // Get conversation context
      final Map<String, dynamic> context = await ChatService.getContextForAI(
        conversationId: currentConversationId.value,
        maxMessages:
            10, // Reducir a 10 mensajes para evitar problemas de tokens
      );

      // Prepare messages for OpenAI API
      final List<Map<String, String>> openaiMessages = [
        {
          'role': 'system',
          'content':
              'You are a helpful AI assistant. Respond in a friendly and helpful manner.',
        },
        ...context['messages']
            .where(
              (Map<String, dynamic> msg) =>
                  msg['role'] !=
                  'system', // Filtrar mensajes de error del sistema
            )
            .map<Map<String, String>>(
              (Map<String, dynamic> msg) => {
                'role': msg['role'] as String,
                'content': _cleanMessageContent(
                  msg['content']['text'] as String? ??
                      msg['content'].toString(),
                ),
              },
            )
            .toList(),
      ];

      // Validar que no haya mensajes vacíos o problemáticos
      final List<Map<String, String>> validMessages = openaiMessages
          .where(
            (msg) =>
                msg['content'] != null &&
                msg['content']!.isNotEmpty &&
                msg['content']!.length <= 4000, // Limitar longitud
          )
          .toList();

      debugPrint(
        'Sending ${validMessages.length} valid messages to OpenAI (${openaiMessages.length} total)',
      );
      for (int i = 0; i < validMessages.length; i++) {
        final msg = validMessages[i];
        final content = msg['content'] ?? '';
        final preview = content.length > 50
            ? '${content.substring(0, 50)}...'
            : content;
        debugPrint('Message $i: ${msg['role']}: $preview');
      }

      // Call OpenAI API
      final String aiResponse = await _callOpenAIAPI(validMessages);

      // Add AI response to chat
      final MessageLocal aiMessage = await ChatService.createAssistantMessage(
        conversationId: currentConversationId.value,
        text: aiResponse,
      );

      messages.add(aiMessage);

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error getting AI response: $e');

      // Add error message to chat
      final MessageLocal errorMessage = await ChatService.createSystemMessage(
        conversationId: currentConversationId.value,
        text: 'Sorry, I encountered an error. Please try again.',
      );

      messages.add(errorMessage);
      _scrollToBottom();
    } finally {
      isTyping.value = false;
    }
  }

  /// Call OpenAI API
  Future<String> _callOpenAIAPI(List<Map<String, String>> messages) async {
    final HttpClient httpClient = HttpClient();

    try {
      // Check if API key is available
      if (openaiKey == null || openaiKey!.isEmpty) {
        throw Exception('OpenAI API key is not configured');
      }

      debugPrint('Using OpenAI API key: ${openaiKey!.substring(0, 8)}...');
      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      // Set headers
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $openaiKey');
      request.headers.set('User-Agent', 'Eidos-Chat-App/1.0');

      // Set request body
      final Map<String, dynamic> requestBody = {
        'model': 'gpt-4o-mini',
        'messages': messages,
        'max_tokens': 1000,
        'temperature': 0.7,
      };

      final String jsonBody = jsonEncode(requestBody);
      debugPrint('JSON Body Length: ${jsonBody.length}');
      debugPrint('JSON Body: $jsonBody');

      request.write(jsonBody);

      // Get response with timeout
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      final String responseBody = await response.transform(utf8.decoder).join();

      debugPrint('OpenAI API Response Status: ${response.statusCode}');
      debugPrint('OpenAI API Response Body: $responseBody');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        return responseData['choices'][0]['message']['content'] as String;
      } else {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - $responseBody',
        );
      }
    } finally {
      httpClient.close();
    }
  }

  /// Update conversation title based on first message
  Future<void> _updateConversationTitle(String firstMessage) async {
    try {
      String title = firstMessage;
      if (title.length > 30) {
        title = '${title.substring(0, 30)}...';
      }

      await ChatService.updateConversationTitle(
        currentConversationId.value,
        title,
      );

      conversationTitle.value = title;
    } catch (e) {
      debugPrint('Error updating conversation title: $e');
    }
  }

  /// Scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Show error snackbar
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red[100],
      colorText: Colors.red[800],
      duration: const Duration(seconds: 3),
    );
  }

  /// Handle quick action taps
  void handleQuickAction(String action) {
    String prompt = '';

    switch (action) {
      case 'Ideas':
        prompt = 'Give me some creative ideas for ';
        break;
      case 'Code':
        prompt = 'Help me write code for ';
        break;
      case 'Write':
        prompt = 'Help me write ';
        break;
    }

    messageController.text = prompt;
  }

  /// Start a new chat
  Future<void> startNewChat() async {
    final NavigationController navController = Get.find<NavigationController>();
    navController.hideChat();

    // Wait a bit then show new chat
    await Future.delayed(const Duration(milliseconds: 300));
    navController.showChat();
  }

  /// Load existing conversation
  Future<void> loadConversation(String conversationId) async {
    try {
      isLoading.value = true;

      // Get conversation
      final ConversationLocal? conversation = await ChatService.getConversation(
        conversationId,
      );
      if (conversation == null) {
        _showErrorSnackbar('Conversation not found');
        return;
      }

      // Get messages
      final List<MessageLocal> conversationMessages =
          await ChatService.getMessages(conversationId);

      // Update state
      currentConversationId.value = conversationId;
      conversationTitle.value = conversation.title ?? 'Chat';
      messages.value = conversationMessages;
      hasMessages.value = conversationMessages.isNotEmpty;

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading conversation: $e');
      _showErrorSnackbar('Error loading conversation');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get conversation statistics
  Future<Map<String, int>> getStats() async {
    return await ChatService.getLocalStats();
  }

  /// Clean message content for OpenAI API
  String _cleanMessageContent(String content) {
    if (content.isEmpty) return content;

    // Remover caracteres problemáticos y normalizar
    return content
        .replaceAll(
          RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
          '',
        ) // Control characters
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
        .trim();
  }
}
