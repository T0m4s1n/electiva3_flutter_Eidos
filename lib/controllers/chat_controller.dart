import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import '../services/chat_service.dart';
import '../services/document_service.dart';
import '../services/hive_storage_service.dart';
import '../services/reminder_service.dart';
import '../models/chat_models.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/preferences_controller.dart';
import '../widgets/document_editor.dart';

class ChatController extends GetxController {
  // Observable variables
  final RxList<MessageLocal> messages = <MessageLocal>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isTyping = false.obs;
  final RxString currentConversationId = ''.obs;
  final RxString conversationTitle = 'New Chat'.obs;
  final RxBool hasMessages = false.obs;
  final RxBool isNewChat = true.obs; // Track if this is a brand new chat

  // Document mode variables
  final RxBool isDocumentMode = false.obs;
  final RxBool isGeneratingDocument = false.obs;
  final Rx<String?> generatedDocument = Rx<String?>(null);
  final Rx<String?> documentTitle = Rx<String?>(null);
  final Rx<String?> currentDocumentId = Rx<String?>(null);

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
      debugPrint('=== Initializing new chat ===');

      // Create a new conversation
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'New Chat',
            model: 'gpt-4o-mini', // Visual selection only - actual model is always gpt-4o-mini
          );

      // Verify the conversation was saved to the database
      final ConversationLocal? verifyConv = await ChatService.getConversation(
        conversation.id,
      );

      if (verifyConv == null) {
        debugPrint('ERROR: Conversation was not saved to database!');
        debugPrint('Conversation ID: ${conversation.id}');
        throw Exception('Failed to save conversation to database');
      } else {
        debugPrint('Verified conversation exists in database');
      }

      // Reset all state
      currentConversationId.value = conversation.id;
      conversationTitle.value = conversation.title ?? 'New Chat';
      hasMessages.value = false;
      isNewChat.value = true; // Mark as new chat
      isDocumentMode.value = false;
      isGeneratingDocument.value = false;
      generatedDocument.value = null;
      documentTitle.value = null;

      // Clear any existing messages
      messages.clear();
      debugPrint('=== Chat initialization complete ===');
    } catch (e) {
      _showErrorSnackbar('Error initializing chat');
    } finally {
      isLoading.value = false;
    }
  }

  /// Detect if the message is requesting document creation
  bool _isDocumentRequest(String messageText) {
    final String lowerMessage = messageText.toLowerCase();

    final List<String> documentKeywords = [
      'crear un documento',
      'escribir un documento',
      'crea un documento',
      'escribe un documento',
      'crear documento',
      'escribir documento',
      'generar un documento',
      'hacer un documento',
      'redactar un documento',
      'componer un documento',
      'elaborar un documento',
      'diseñar un documento',
      'crear un texto',
      'escribir un texto',
      'redactar un texto',
      'hacer una redacción',
      'crear un escrito',
      'elaborar un escrito',
      'create a document',
      'write a document',
      'make a document',
      'generate a document',
      'compose a document',
      'draft a document',
    ];

    return documentKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Send a message to the chat
  Future<void> sendMessage() async {
    final String messageText = messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      isLoading.value = true;

      // Clear input
      messageController.clear();

      // Check if message is requesting document creation
      final bool isDocumentRequest = _isDocumentRequest(messageText);

      // Check if we're in document mode OR if this is a document request
      if (isDocumentMode.value || isDocumentRequest) {
        // If not already in document mode, activate it
        if (!isDocumentMode.value) {
          debugPrint('Document mode activated from message: $messageText');
          isDocumentMode.value = true;
        }

        // In document mode, generate document with checklist
        await generateDocumentWithChecklist(messageText);
      } else {
        // Regular chat mode
        // Add user message to the chat

        final MessageLocal userMessage = await ChatService.createUserMessage(
          conversationId: currentConversationId.value,
          text: messageText,
        );

        // Verify the message was saved to database
        await Future.delayed(
          const Duration(milliseconds: 200),
        ); // Give time for DB to save
        final List<MessageLocal> verifyMessages = await ChatService.getMessages(
          currentConversationId.value,
        );
        final int userMsgCount = verifyMessages
            .where((m) => m.role == 'user')
            .length;
        debugPrint(
          'Verification: Found ${verifyMessages.length} total messages in database',
        );
        debugPrint(
          'Verification: Found $userMsgCount user messages in database',
        );

        messages.add(userMessage);
        hasMessages.value = true;

        debugPrint(
          'Added user message to observable list. Total messages: ${messages.length}',
        );

        // Update conversation title and generate context if it's the first message
        if (messages.length == 1) {
          await _updateConversationTitle(messageText);

          // Generate and save context for personalized AI responses
          await _generateAndSaveContext(messageText);
        }

        // Scroll to bottom
        _scrollToBottom();

        // Check for reminder request before sending to AI
        // Pass document mode context to help differentiate between reminder requests and document editing
        final reminderData = ReminderService.parseReminderFromMessage(
          messageText,
          isDocumentMode: isDocumentMode.value,
        );
        if (reminderData != null) {
          try {
            final reminderDate = reminderData['reminder_date'] as DateTime;
            final reminderTitle = reminderData['title'] as String;
            
            await ReminderService.createReminderFromChat(
              title: reminderTitle,
              description: reminderData['description'] as String?,
              reminderDate: reminderDate,
              conversationId: currentConversationId.value,
              messageId: userMessage.id,
            );

            // Calculate time until reminder
            final DateTime now = DateTime.now();
            final Duration timeUntilReminder = reminderDate.difference(now);
            final String timeUntilReminderText = _formatTimeUntilReminder(timeUntilReminder);

            // Add confirmation message to chat
            final MessageLocal confirmationMessage = await ChatService.createAssistantMessage(
              conversationId: currentConversationId.value,
              text: '✅ Reminder created: "$reminderTitle" at ${_formatReminderDate(reminderDate)}',
            );
            messages.add(confirmationMessage);
            hasMessages.value = true;
            _scrollToBottom();

            // Show snackbar
            Get.snackbar(
              'Reminder Created',
              'Reminder set for ${_formatReminderDate(reminderDate)}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green[100],
              colorText: Colors.green[800],
              duration: const Duration(seconds: 2),
            );

            // Still get AI response with reminder context
            // Add a system message about the reminder so AI can mention when notification will be sent
            final String reminderContextMessage = 'A reminder has been created: "$reminderTitle" scheduled for ${_formatReminderDate(reminderDate)}. The user will receive a notification in $timeUntilReminderText. Acknowledge this and let them know when they will receive the notification.';
            
            await Future.delayed(const Duration(milliseconds: 300));
            await _getAIResponseWithReminderContext(reminderContextMessage, messageText);
          } catch (e) {
            debugPrint('Error creating reminder: $e');
            Get.snackbar(
              'Error',
              'Failed to create reminder: $e',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.red[100],
              colorText: Colors.red[800],
              duration: const Duration(seconds: 2),
            );
            // Continue with normal AI response
            await Future.delayed(const Duration(milliseconds: 300));
            await _getAIResponse(messageText);
          }
        } else {
          // Wait a bit longer to ensure the message is fully saved and indexed in the database
          await Future.delayed(const Duration(milliseconds: 300));

          // Get AI response - pass the message text explicitly to ensure it's used
          await _getAIResponse(messageText);
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showErrorSnackbar('Error sending message');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get AI response with reminder context
  Future<void> _getAIResponseWithReminderContext(String reminderContext, String userMessage) async {
    if (openaiKey == null) {
      _showErrorSnackbar('OpenAI API key not configured');
      return;
    }

    try {
      isTyping.value = true;

      // Clear system error messages
      await ChatService.clearSystemErrorMessages(currentConversationId.value);

      // Get conversation context
      final List<Map<String, dynamic>> formattedMessages = messages
          .map(
            (MessageLocal msg) => {
              'id': msg.id,
              'role': msg.role,
              'content': msg.content,
              'created_at': msg.createdAt,
              'seq': msg.seq,
            },
          )
          .toList();

      // Build messages for OpenAI with reminder context
      final List<Map<String, String>> openaiMessages = [
        {
          'role': 'system',
          'content': 'You are a helpful AI assistant. When a reminder has been created, acknowledge it and let the user know when they will receive the notification. Be concise and friendly.',
        },
        {
          'role': 'system',
          'content': reminderContext,
        },
        ...formattedMessages.map((msg) {
          final content = msg['content'];
          String textContent = '';
          if (content is Map) {
            textContent = content['text'] as String? ?? content.toString();
          } else {
            textContent = content.toString();
          }

          return {
            'role': msg['role'] as String,
            'content': _cleanMessageContent(textContent),
          };
        }).toList(),
        {
          'role': 'user',
          'content': _cleanMessageContent(userMessage),
        },
      ];

      // Filter valid messages
      final List<Map<String, String>> validMessages = openaiMessages
          .where(
            (msg) =>
                msg['content'] != null &&
                msg['content']!.isNotEmpty &&
                msg['content']!.length <= 4000,
          )
          .toList();

      // Call OpenAI API
      debugPrint('Calling OpenAI API with reminder context');
      final String aiResponse = await _callOpenAIAPI(validMessages);

      // Validate the response
      if (aiResponse.isEmpty || aiResponse.trim().isEmpty || aiResponse == '0') {
        throw Exception('Invalid or empty response from AI');
      }

      final MessageLocal aiMessage = await ChatService.createAssistantMessage(
        conversationId: currentConversationId.value,
        text: aiResponse,
      );

      messages.add(aiMessage);
      await Future.delayed(const Duration(milliseconds: 200));
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error getting AI response with reminder context: $e');
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

      // Get conversation context from local messages list first
      Map<String, dynamic> context;
      try {
        // Use local messages from the observable list as they're already loaded and up-to-date
        final List<Map<String, dynamic>> formattedMessages = messages
            .map(
              (MessageLocal msg) => {
                'id': msg.id,
                'role': msg.role,
                'content': msg.content,
                'created_at': msg.createdAt,
                'seq': msg.seq,
              },
            )
            .toList();

        debugPrint(
          'Using local messages: ${formattedMessages.length} messages',
        );
        for (int i = 0; i < formattedMessages.length; i++) {
          final msg = formattedMessages[i];
          debugPrint(
            'Local message $i: role=${msg['role']}, content=${msg['content']}',
          );
        }

        context = {
          'conversation': {
            'id': currentConversationId.value,
            'title': conversationTitle.value,
          },
          'messages': formattedMessages,
          'total_messages': formattedMessages.length,
        };
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
            },
          ],
        };
      }

      // Get the conversation context for personalized system message
      String systemMessageContent =
          'You are a helpful AI assistant. Respond in a friendly and helpful manner.';
      try {
        final PreferencesController preferencesController =
            Get.find<PreferencesController>();
        systemMessageContent = preferencesController.currentSystemPrompt;
        debugPrint(
          'Using AI personality: ${preferencesController.aiPersonality.value.displayName}',
        );

        // Log if there are custom rules
        if (preferencesController.chatRules.isNotEmpty) {
          debugPrint(
            'Applying ${preferencesController.chatRules.length} custom chat rules',
          );
          debugPrint('Full system prompt: $systemMessageContent');
        } else {
          debugPrint('No custom rules found');
        }
      } catch (e) {
        debugPrint('Error getting preferences controller: $e');
      }

      try {
        final ConversationLocal? conversation =
            await ChatService.getConversation(currentConversationId.value);
        if (conversation?.summary != null &&
            conversation!.summary!.isNotEmpty) {
          // Combine personalized context with custom rules
          String contextMessage = _getSystemMessage(conversation.summary!);
          systemMessageContent = '$systemMessageContent\n\n$contextMessage';
          debugPrint(
            'Using personalized system message for context: ${conversation.summary}',
          );
        }
      } catch (e) {
        debugPrint('Error getting conversation context: $e');
      }

      // Prepare messages for OpenAI API
      final List<Map<String, String>> openaiMessages = [
        {'role': 'system', 'content': systemMessageContent},
        ...context['messages']
            .where(
              (Map<String, dynamic> msg) =>
                  msg['role'] !=
                  'system', // Filtrar mensajes de error del sistema
            )
            .map<Map<String, String>>((Map<String, dynamic> msg) {
              // Extract text content properly
              String textContent = '';
              try {
                final dynamic contentRaw = msg['content'];

                if (contentRaw == null) {
                  debugPrint(
                    'Warning: Content is null for message: ${msg['id']}',
                  );
                  textContent = '';
                } else if (contentRaw is Map) {
                  final Map<String, dynamic> content =
                      contentRaw as Map<String, dynamic>;
                  textContent = content['text'] as String? ?? '';

                  // If text is empty, try to get any string value from the map
                  if (textContent.isEmpty && content.isNotEmpty) {
                    final firstValue = content.values.first;
                    textContent = firstValue is String
                        ? firstValue
                        : firstValue.toString();
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
                debugPrint(
                  'Warning: Empty message content for message: ${msg['id']}',
                );
              }

              return {
                'role': msg['role'] as String,
                'content': _cleanMessageContent(textContent),
              };
            })
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
        debugPrint(
          'Warning: Only ${validMessages.length} valid messages. Adding user message manually.',
        );
        // If we don't have enough messages, add the user message directly
        validMessages.add({
          'role': 'user',
          'content': _cleanMessageContent(userMessage),
        });
        debugPrint(
          'Added user message directly. Total messages: ${validMessages.length}',
        );
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
      debugPrint(
        'Received AI response: ${aiResponse.substring(0, aiResponse.length > 100 ? 100 : aiResponse.length)}...',
      );

      // Validate the response
      if (aiResponse.isEmpty ||
          aiResponse.trim().isEmpty ||
          aiResponse == '0') {
        throw Exception('Invalid or empty response from AI');
      }

      final MessageLocal aiMessage = await ChatService.createAssistantMessage(
        conversationId: currentConversationId.value,
        text: aiResponse,
      );

      debugPrint('AI message created with ID: ${aiMessage.id}');
      debugPrint('AI message role: ${aiMessage.role}');
      debugPrint('AI message seq: ${aiMessage.seq}');

      messages.add(aiMessage);

      // Wait for database to persist
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify AI message was saved
      final List<MessageLocal> savedMessages = await ChatService.getMessages(
        currentConversationId.value,
      );
      final int assistantMsgCount = savedMessages
          .where((m) => m.role == 'assistant')
          .length;
      final int userMsgCount = savedMessages
          .where((m) => m.role == 'user')
          .length;
      debugPrint(
        'Total messages in conversation after AI response: ${savedMessages.length}',
      );
      debugPrint('  - User messages: $userMsgCount');
      debugPrint('  - Assistant messages: $assistantMsgCount');

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
        'model': 'gpt-4o-mini', // Visual selection only - actual model is always gpt-4o-mini
        'messages': messages,
        'max_tokens': HiveStorageService.loadMaxTokens(),
        'temperature': 0.7, // Default value
        'top_p': 1.0, // Default value
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

  /// Handle document creation
  Future<void> handleDocumentCreation() async {
    try {
      debugPrint('Starting document creation...');

      // Clear current messages if any
      messages.clear();

      // Initialize a new chat conversation for document editing
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'Document Editor',
            model: 'gpt-4o-mini', // Visual selection only - actual model is always gpt-4o-mini
          );

      debugPrint('Created new document conversation: ${conversation.id}');

      // Update state
      currentConversationId.value = conversation.id;
      conversationTitle.value = conversation.title ?? 'Document Editor';
      hasMessages.value = false;
      isDocumentMode.value = true;

      // Add a system message to guide the user
      final MessageLocal systemMessage = await ChatService.createSystemMessage(
        conversationId: currentConversationId.value,
        text:
            'I am ready to help you create and edit documents! What would you like to write or edit?',
      );

      messages.add(systemMessage);
      hasMessages.value = messages.isNotEmpty;

      debugPrint('Document creation initialized');
    } catch (e) {
      debugPrint('Error in handleDocumentCreation: $e');
      _showErrorSnackbar('Error starting document creation');
    }
  }

  /// Generate document with checklist thinking
  Future<void> generateDocumentWithChecklist(String userRequest) async {
    try {
      debugPrint('Starting document generation with AI checklist...');
      isGeneratingDocument.value = true;

      // Add user message
      final MessageLocal userMessage = await ChatService.createUserMessage(
        conversationId: currentConversationId.value,
        text: userRequest,
      );
      messages.add(userMessage);
      hasMessages.value = true;

      // Generate checklist using AI
      isTyping.value = true;
      final String aiChecklist = await _generateDocumentChecklist(userRequest);
      isTyping.value = false;

      // Show AI-generated checklist message
      final MessageLocal checklistMessage =
          await ChatService.createAssistantMessage(
            conversationId: currentConversationId.value,
            text: aiChecklist,
          );
      messages.add(checklistMessage);

      // Scroll to show the checklist message
      _scrollToBottom();

      // Wait longer for user to read the checklist before starting document generation
      await Future.delayed(const Duration(milliseconds: 2500));

      // Now generate the actual document (show typing indicator)
      isTyping.value = true;
      _scrollToBottom();

      // Generate the document content
      final String documentContent = await _generateDocumentContent(
        userRequest,
      );
      isTyping.value = false;

      // Wait a bit before showing completion to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 300));

      // Show completion message only after document is fully generated
      final MessageLocal completedMessage =
          await ChatService.createAssistantMessage(
            conversationId: currentConversationId.value,
            text: '''✅ Document generated successfully!

Your document is ready. Tap this message to open the editor and view your document.''',
          );
      messages.add(completedMessage);

      // Store the generated document
      generatedDocument.value = documentContent;
      documentTitle.value = _extractTitleFromRequest(userRequest);

      // Save the document locally first, then to Supabase
      String? documentId;
      try {
        documentId = await DocumentService.saveDocument(
          conversationId: currentConversationId.value,
          title: documentTitle.value!,
          content: documentContent,
        );
        currentDocumentId.value = documentId;
        debugPrint('Document saved successfully with ID: $documentId');
      } catch (e) {
        debugPrint('Error saving document: $e');
        // Continue even if saving fails
      }

      // Also save the document content as a special message in the database
      await ChatService.addMessage(
        conversationId: currentConversationId.value,
        role: 'assistant',
        content: {'text': documentContent, 'type': 'document'},
        status: 'ok',
      );

      isGeneratingDocument.value = false;

      // Auto-scroll
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error generating document: $e');
      isGeneratingDocument.value = false;
      isTyping.value = false;
      _showErrorSnackbar('Error generating document');

      // Add error message
      final MessageLocal errorMessage = await ChatService.createSystemMessage(
        conversationId: currentConversationId.value,
        text:
            'Sorry, I encountered an error while generating your document. Please try again.',
      );
      messages.add(errorMessage);
    }
  }

  /// Generate checklist for document creation using AI
  Future<String> _generateDocumentChecklist(String userRequest) async {
    if (openaiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    final HttpClient httpClient = HttpClient();
    try {
      debugPrint('Calling OpenAI to generate document checklist...');

      // Prepare system message for checklist generation
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content':
              '''You are a helpful assistant that creates planning checklists for document creation.
          
When given a document request, create a brief checklist (4-6 items) showing the steps you'll take to create it.

Format your response as:
📋 Planning your document...

✓ [First step]
✓ [Second step]
✓ [Third step]
✓ [Fourth step]
⏳ Generating your document now...

Keep it concise, relevant, and focused on the specific document type requested.''',
        },
        {'role': 'user', 'content': userRequest},
      ];

      // Call OpenAI API
      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $openaiKey');
      request.headers.set('User-Agent', 'Eidos-Chat-App/1.0');

      final Map<String, dynamic> requestBody = {
        'model': 'gpt-4o-mini', // Visual selection only - actual model is always gpt-4o-mini
        'messages': messages,
        'max_tokens': 200, // Checklist generation uses shorter responses
        'temperature': 0.7, // Default value
        'top_p': 1.0, // Default value
      };

      request.write(jsonEncode(requestBody));

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout after 30 seconds');
        },
      );

      final String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(responseBody);

        if (responseData['choices'] == null ||
            responseData['choices'].isEmpty) {
          throw Exception('No choices in OpenAI response');
        }

        final Map<String, dynamic> firstChoice = responseData['choices'][0];
        final Map<String, dynamic> message = firstChoice['message'];
        final String? content = message['content'] as String?;

        if (content == null || content.isEmpty) {
          throw Exception('Empty response from OpenAI');
        }

        return content;
      } else {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      debugPrint('Error calling OpenAI for checklist: $e');
      // Return a fallback checklist if AI fails
      return '''📋 Planning your document...

✓ Understanding your requirements
✓ Structuring the content
✓ Preparing sections
✓ Organizing information
⏳ Generating your document now...''';
    } finally {
      httpClient.close();
    }
  }

  /// Generate document content using AI
  Future<String> _generateDocumentContent(String userRequest) async {
    if (openaiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    final HttpClient httpClient = HttpClient();
    try {
      debugPrint('Calling OpenAI to generate document...');

      // Prepare system message for document generation
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content':
              '''You are a helpful document writing assistant. Create well-structured, professional documents based on user requests.
          
Your response should be a complete document with:
- A clear title using ## (H2) for the main title
- Introduction section
- Main body content with sections using ### (H3) for subsections
- Conclusion
- Professional formatting

Use markdown formatting throughout:
- ## for main sections (H2 headers)
- ### for subsections (H3 headers)
- **bold** for emphasis
- *italic* for subtle emphasis
- - or * for bullet points
- 1. for numbered lists
- `code` for inline code
- > for blockquotes
- --- for horizontal rules

Make it comprehensive and ready to use with proper markdown formatting.''',
        },
        {'role': 'user', 'content': userRequest},
      ];

      // Call OpenAI API
      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $openaiKey');
      request.headers.set('User-Agent', 'Eidos-Chat-App/1.0');

      final Map<String, dynamic> requestBody = {
        'model': 'gpt-4o-mini', // Visual selection only - actual model is always gpt-4o-mini
        'messages': messages,
        'max_tokens': HiveStorageService.loadMaxTokens(),
        'temperature': 0.7, // Default value
        'top_p': 1.0, // Default value
      };

      request.write(jsonEncode(requestBody));

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout after 60 seconds');
        },
      );

      final String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(responseBody);

        if (responseData['choices'] == null ||
            responseData['choices'].isEmpty) {
          throw Exception('No choices in OpenAI response');
        }

        final Map<String, dynamic> firstChoice = responseData['choices'][0];
        final Map<String, dynamic> message = firstChoice['message'];
        final String? content = message['content'] as String?;

        if (content == null || content.isEmpty) {
          throw Exception('Empty response from OpenAI');
        }

        return content;
      } else {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      debugPrint('Error calling OpenAI: $e');
      rethrow;
    } finally {
      httpClient.close();
    }
  }

  /// Extract title from user request
  String _extractTitleFromRequest(String request) {
    // Try to extract a meaningful title
    final String lowerRequest = request.toLowerCase();

    if (lowerRequest.contains('resume') || lowerRequest.contains('cv')) {
      return 'My Resume';
    } else if (lowerRequest.contains('letter')) {
      return 'Letter';
    } else if (lowerRequest.contains('report')) {
      return 'Report';
    } else if (lowerRequest.contains('proposal')) {
      return 'Proposal';
    } else if (lowerRequest.contains('essay')) {
      return 'Essay';
    } else {
      // Use first part of request as title
      final String title = request.length > 30
          ? '${request.substring(0, 30)}...'
          : request;
      return title;
    }
  }

  /// Open the document editor
  void openDocumentEditor() {
    try {
      final String? document = generatedDocument.value;
      final String? title = documentTitle.value;
      final String? docId = currentDocumentId.value;

      debugPrint('Attempting to open document editor...');
      debugPrint(
        'Document available: ${document != null && document.isNotEmpty}',
      );
      debugPrint('Document length: ${document?.length ?? 0}');
      debugPrint('Title: $title');
      debugPrint('Document ID: $docId');

      if (document != null && document.isNotEmpty) {
        debugPrint(
          'Opening DocumentEditor with content length: ${document.length}',
        );
        Get.to(
          () => DocumentEditor(
            documentTitle: title ?? 'Document',
            documentContent: document,
            documentId: docId,
          ),
        );
        debugPrint('Document editor opened successfully');
      } else {
        debugPrint('No document available - showing error snackbar');
        _showErrorSnackbar('No document available to open');
      }
    } catch (e, stackTrace) {
      debugPrint('Error opening document editor: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorSnackbar('Error opening document editor: $e');
    }
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
      // IMPORTANT: Don't show typing animation when loading saved chats
      isTyping.value = false;

      debugPrint('=== ChatController.loadConversation started ===');
      debugPrint('Conversation ID: $conversationId');
      debugPrint('isTyping set to FALSE for loading saved chat');

      // Get conversation
      final ConversationLocal? conversation = await ChatService.getConversation(
        conversationId,
      );
      if (conversation == null) {
        debugPrint('ERROR: Conversation not found with ID: $conversationId');
        _showErrorSnackbar('Conversation not found');
        return;
      }
      debugPrint('Found conversation: ${conversation.title}');

      // Get messages
      debugPrint('Fetching messages from database...');
      final List<MessageLocal> conversationMessages =
          await ChatService.getMessages(conversationId);

      debugPrint(
        '=== Database returned ${conversationMessages.length} messages ===',
      );

      // Count messages by role
      final int userCount = conversationMessages
          .where((m) => m.role == 'user')
          .length;
      final int assistantCount = conversationMessages
          .where((m) => m.role == 'assistant')
          .length;
      final int systemCount = conversationMessages
          .where((m) => m.role == 'system')
          .length;

      debugPrint('Message breakdown:');
      debugPrint('  - User messages: $userCount');
      debugPrint('  - Assistant messages: $assistantCount');
      debugPrint('  - System messages: $systemCount');

      // Log each message for debugging
      for (int i = 0; i < conversationMessages.length; i++) {
        final msg = conversationMessages[i];
        final content = msg.content;
        final text = content['text'] as String? ?? content.toString();
        debugPrint(
          'Message $i: role=${msg.role}, seq=${msg.seq}, id=${msg.id}',
        );
        debugPrint(
          '  Content preview: ${text.length > 50 ? text.substring(0, 50) + "..." : text}',
        );
      }

      // Update state
      currentConversationId.value = conversationId;
      conversationTitle.value = conversation.title ?? 'Chat';
      isNewChat.value = false; // Mark as loaded chat (not new)

      // Clear and set messages
      debugPrint('Clearing existing messages (count: ${messages.length})');
      messages.clear();
      debugPrint(
        'Adding ${conversationMessages.length} messages to observable list',
      );
      messages.addAll(conversationMessages);
      messages.refresh(); // Force reactivity update

      hasMessages.value = conversationMessages.isNotEmpty;

      debugPrint(
        '=== Chat controller updated with ${messages.length} messages ===',
      );
      debugPrint('hasMessages.value = ${hasMessages.value}');

      // Check for any document messages and restore them
      for (final MessageLocal message in conversationMessages) {
        final Map<String, dynamic> content = message.content;
        if (content['type'] == 'document' && content['text'] != null) {
          generatedDocument.value = content['text'] as String;
          documentTitle.value = conversation.title ?? 'Document';
          isDocumentMode.value = true;
          break; // Only need to restore the first document
        }
      }

      // Scroll to bottom
      _scrollToBottom();

      debugPrint('=== Chat loading complete ===');
    } catch (e) {
      debugPrint('Error loading conversation: $e');
      _showErrorSnackbar('Error loading conversation');
    } finally {
      isLoading.value = false;
      // Ensure typing animation is disabled when loading is done
      isTyping.value = false;
      debugPrint('Loading complete - isTyping = ${isTyping.value}');
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

  /// Format time until reminder
  String _formatTimeUntilReminder(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'less than a minute';
    } else if (duration.inMinutes < 60) {
      final minutes = duration.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} and $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      }
    } else {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (hours == 0) {
        return '$days ${days == 1 ? 'day' : 'days'}';
      } else {
        return '$days ${days == 1 ? 'day' : 'days'} and $hours ${hours == 1 ? 'hour' : 'hours'}';
      }
    }
  }

  /// Format reminder date for display
  String _formatReminderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDay = DateTime(date.year, date.month, date.day);
    final difference = reminderDay.difference(today).inDays;

    if (difference == 0) {
      // Today
      return 'today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      // Tomorrow
      return 'tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference < 7) {
      // This week
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return '${weekdays[date.weekday - 1]} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // Future date
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
