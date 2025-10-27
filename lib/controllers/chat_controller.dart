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
      debugPrint('Initializing new chat...');

      // Create a new conversation
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'New Chat',
            model: 'gpt-4o-mini',
          );

      debugPrint('Created new conversation: ${conversation.id}');

      // Reset all state
      currentConversationId.value = conversation.id;
      conversationTitle.value = conversation.title ?? 'New Chat';
      hasMessages.value = false;

      // Clear any existing messages
      messages.clear();

      debugPrint(
        'Chat initialized - ID: ${conversation.id}, Messages: ${messages.length}',
      );
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

      // Update conversation title and generate context if it's the first message
      if (messages.length == 1) {
        await _updateConversationTitle(messageText);
        
        // Generate and save context for personalized AI responses
        await _generateAndSaveContext(messageText);
      }

      // Scroll to bottom
      _scrollToBottom();

      // Wait a bit longer to ensure the message is fully saved and indexed in the database
      await Future.delayed(const Duration(milliseconds: 300));

      // Get AI response - pass the message text explicitly to ensure it's used
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
      Map<String, dynamic> context;
      try {
        context = await ChatService.getContextForAI(
          conversationId: currentConversationId.value,
          maxMessages: 10,
        );
        
        debugPrint('Context retrieved successfully with ${context['messages'].length} messages');
        
        // Check if the user's current message is in the context
        final bool hasUserMessage = context['messages'].any(
          (msg) => msg['role'] == 'user' && 
                   _extractTextFromContent(msg['content']) == userMessage
        );
        
        if (!hasUserMessage) {
          debugPrint('User message not found in context, adding it manually');
          // Add the user message if it's not in the context yet
          context['messages'].add({
            'id': 'temp',
            'role': 'user',
            'content': {'text': userMessage},
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'seq': 999999,
          });
        }
      } catch (e) {
        debugPrint('Error getting context, using fallback: $e');
        // Fallback: create a minimal context with just the current user message
        context = {
          'conversation': {'id': currentConversationId.value},
          'messages': [
            {
              'id': 'temp',
              'role': 'user',
              'content': {'text': userMessage},
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'seq': 0,
            }
          ],
        };
      }

      // Get the conversation context for personalized system message
      String systemMessageContent = 'You are a helpful AI assistant. Respond in a friendly and helpful manner.';
      try {
        final ConversationLocal? conversation = await ChatService.getConversation(
          currentConversationId.value,
        );
        if (conversation?.summary != null && conversation!.summary!.isNotEmpty) {
          systemMessageContent = _getSystemMessage(conversation.summary!);
          debugPrint('Using personalized system message for context: ${conversation.summary}');
        }
      } catch (e) {
        debugPrint('Error getting conversation context: $e');
      }

      // Prepare messages for OpenAI API
      final List<Map<String, String>> openaiMessages = [
        {
          'role': 'system',
          'content': systemMessageContent,
        },
        ...context['messages']
            .where(
              (Map<String, dynamic> msg) =>
                  msg['role'] !=
                  'system', // Filtrar mensajes de error del sistema
            )
            .map<Map<String, String>>(
              (Map<String, dynamic> msg) {
                // Extract text content properly
                String textContent = '';
                try {
                  final dynamic contentRaw = msg['content'];
                  
                  if (contentRaw == null) {
                    debugPrint('Warning: Content is null for message: ${msg['id']}');
                    textContent = '';
                  } else if (contentRaw is Map) {
                    final Map<String, dynamic> content = contentRaw as Map<String, dynamic>;
                    textContent = content['text'] as String? ?? '';
                    
                    // If text is empty, try to get any string value from the map
                    if (textContent.isEmpty && content.isNotEmpty) {
                      final firstValue = content.values.first;
                      textContent = firstValue is String ? firstValue : firstValue.toString();
                    }
                  } else if (contentRaw is String) {
                    textContent = contentRaw;
                  } else {
                    textContent = contentRaw.toString();
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error extracting message content: $e');
                  debugPrint('Stack trace: $stackTrace');
                  debugPrint('Message data: $msg');
                  textContent = '';
                }
                
                // Validate that we have valid content
                if (textContent.isEmpty) {
                  debugPrint('Warning: Empty message content for message: ${msg['id']}');
                }
                
                return {
                  'role': msg['role'] as String,
                  'content': _cleanMessageContent(textContent),
                };
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
      
      // Ensure we have at least a system message and one user message
      if (validMessages.length < 2) {
        debugPrint('Warning: Only ${validMessages.length} valid messages. Adding user message manually.');
        // If we don't have enough messages, add the user message directly
        validMessages.add({
          'role': 'user',
          'content': _cleanMessageContent(userMessage),
        });
        debugPrint('Added user message directly. Total messages: ${validMessages.length}');
      }
      
      for (int i = 0; i < validMessages.length; i++) {
        final msg = validMessages[i];
        final content = msg['content'] ?? '';
        final preview = content.length > 50
            ? '${content.substring(0, 50)}...'
            : content;
        debugPrint('Message $i: ${msg['role']}: $preview');
      }

      // Call OpenAI API
      debugPrint('Calling OpenAI API with ${validMessages.length} messages');
      final String aiResponse = await _callOpenAIAPI(validMessages);
      debugPrint('Received AI response: ${aiResponse.substring(0, aiResponse.length > 100 ? 100 : aiResponse.length)}...');

      // Validate the response
      if (aiResponse.isEmpty || aiResponse.trim().isEmpty || aiResponse == '0') {
        throw Exception('Invalid or empty response from AI');
      }

      // Add AI response to chat
      final MessageLocal aiMessage = await ChatService.createAssistantMessage(
        conversationId: currentConversationId.value,
        text: aiResponse,
      );

      messages.add(aiMessage);
      debugPrint('AI message added to chat with ID: ${aiMessage.id}');

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
        
        // Validate the response structure
        if (responseData['choices'] == null || 
            responseData['choices'].isEmpty) {
          throw Exception('No choices in OpenAI response');
        }
        
        final Map<String, dynamic> firstChoice = responseData['choices'][0];
        final Map<String, dynamic> message = firstChoice['message'];
        final String? content = message['content'] as String?;
        
        if (content == null || content.isEmpty || content.trim() == '0') {
          throw Exception('Empty or invalid response from OpenAI');
        }
        
        return content;
      } else {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      debugPrint('Error parsing OpenAI response: $e');
      rethrow;
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

  /// Generate context from user's message to personalize the AI response
  Future<void> _generateAndSaveContext(String userMessage) async {
    try {
      // Extract keywords and intent from the user's message
      final String context = _extractContext(userMessage);
      
      // Save the context as a system message or conversation summary
      await ChatService.updateConversationSummary(
        currentConversationId.value,
        context,
      );
      
      debugPrint('Generated context: $context');
    } catch (e) {
      debugPrint('Error generating context: $e');
    }
  }

  /// Extract context/intent from user message
  String _extractContext(String message) {
    final String lowerMessage = message.toLowerCase();
    
    // Detect common intents and topics
    if (lowerMessage.contains('codigo') || 
        lowerMessage.contains('code') ||
        lowerMessage.contains('programar') ||
        lowerMessage.contains('programming')) {
      return 'programming_assistant';
    } else if (lowerMessage.contains('explica') ||
               lowerMessage.contains('explain') ||
               lowerMessage.contains('que es') ||
               lowerMessage.contains('what is')) {
      return 'educational_explanation';
    } else if (lowerMessage.contains('ayuda') ||
               lowerMessage.contains('help') ||
               lowerMessage.contains('como puedo') ||
               lowerMessage.contains('how can i')) {
      return 'support_assistant';
    } else if (lowerMessage.contains('creative') ||
               lowerMessage.contains('creativo') ||
               lowerMessage.contains('idea') ||
               lowerMessage.contains('idear')) {
      return 'creative_brainstorming';
    } else if (lowerMessage.contains('traducir') ||
               lowerMessage.contains('translate') ||
               lowerMessage.contains('idioma') ||
               lowerMessage.contains('language')) {
      return 'translation_assistant';
    } else if (lowerMessage.contains('escribir') ||
               lowerMessage.contains('write') ||
               lowerMessage.contains('redactar') ||
               lowerMessage.contains('composicion')) {
      return 'writing_assistant';
    } else {
      return 'general_assistant';
    }
  }

  /// Get personalized system message based on context
  String _getSystemMessage(String context) {
    switch (context) {
      case 'programming_assistant':
        return 'You are a helpful programming assistant. You help users with code, debugging, and technical questions. Provide clear, well-documented solutions.';
      case 'educational_explanation':
        return 'You are an educational assistant. You explain concepts clearly and help users learn. Provide detailed, easy-to-understand explanations.';
      case 'support_assistant':
        return 'You are a helpful support assistant. You provide assistance and guidance to help users solve problems and achieve their goals.';
      case 'creative_brainstorming':
        return 'You are a creative brainstorming assistant. You help generate creative ideas, solutions, and innovative approaches to problems.';
      case 'translation_assistant':
        return 'You are a translation and language assistant. You help with translations and language-related questions.';
      case 'writing_assistant':
        return 'You are a writing assistant. You help with writing, editing, and improving text content.';
      default:
        return 'You are a helpful AI assistant. Respond in a friendly and helpful manner, tailoring your responses to the user\'s needs.';
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
    try {
      isLoading.value = true;
      debugPrint('Starting new chat...');

      final NavigationController navController =
          Get.find<NavigationController>();

      // Hide current chat view
      navController.hideChat();
      debugPrint('Hidden current chat view');

      // Wait a bit for animation
      await Future.delayed(const Duration(milliseconds: 300));

      // Initialize a completely new chat
      await initializeChat();
      debugPrint('Initialized new chat');

      // Show the new chat view
      navController.showChat();
      debugPrint('Showed new chat view');
    } catch (e) {
      debugPrint('Error starting new chat: $e');
      _showErrorSnackbar('Error starting new chat');
    } finally {
      isLoading.value = false;
    }
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

  /// Extract text from content (handles different content formats)
  String _extractTextFromContent(dynamic content) {
    try {
      if (content == null) return '';
      
      if (content is Map<String, dynamic>) {
        return content['text'] as String? ?? '';
      } else if (content is String) {
        return content;
      } else {
        return content.toString();
      }
    } catch (e) {
      debugPrint('Error extracting text from content: $e');
      return '';
    }
  }
}
