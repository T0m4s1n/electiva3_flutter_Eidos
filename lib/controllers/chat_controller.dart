import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
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

  // Cancel token for stopping generation
  HttpClientRequest? _currentRequest;
  HttpClient? _currentHttpClient;
  StreamSubscription<String>? _currentStreamSubscription;
  bool _isStopped = false;
  Completer<String>? _currentGenerationCompleter;

  // OpenAI API key
  String? get openaiKey => dotenv.env['OPENAI_KEY'];


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

  /// Calculate Levenshtein distance between two strings (for typo tolerance)
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Check if a word matches a keyword with typo tolerance
  bool _fuzzyMatch(String word, String keyword, {int maxDistance = 2}) {
    if (word.length < 3) return word == keyword;
    
    // Exact match
    if (word == keyword) return true;
    
    // Check if word contains keyword or vice versa (for partial matches)
    if (word.contains(keyword) || keyword.contains(word)) return true;
    
    // Calculate Levenshtein distance
    final distance = _levenshteinDistance(word, keyword);
    final maxAllowedDistance = (keyword.length * 0.3).ceil().clamp(1, maxDistance);
    
    return distance <= maxAllowedDistance;
  }

  /// Detect if the message is requesting document creation (with typo tolerance)
  bool _isDocumentRequest(String messageText) {
    final String lowerMessage = messageText.toLowerCase().trim();

    // Base keywords for document creation
    final List<String> actionKeywords = [
      'crear', 'crea',
      'escribir', 'escribe',
      'generar', 'genera',
      'hacer', 'haz',
      'redactar', 'redacta',
      'componer', 'compone',
      'elaborar', 'elabora',
      'diseñar', 'diseña',
      'create', 'write', 'make', 'generate', 'compose', 'draft',
    ];

    final List<String> documentKeywords = [
      'documento', 'document',
      'texto', 'text',
      'escrito', 'escrit',
      'redacción', 'redaccion',
    ];

    // Check for action + document pattern (e.g., "crea un documento")
    for (final action in actionKeywords) {
      for (final doc in documentKeywords) {
        // Check exact patterns
        final patterns = [
          '$action un $doc',
          '$action $doc',
          '$action un $doc',
          '$action me un $doc',
          '$action me $doc',
        ];

        for (final pattern in patterns) {
          if (lowerMessage.contains(pattern)) return true;
        }

        // Check with fuzzy matching for typos
        final words = lowerMessage.split(RegExp(r'\s+'));
        for (int i = 0; i < words.length - 1; i++) {
          final word1 = words[i].replaceAll(RegExp(r'[^\w]'), '');
          final word2 = words[i + 1].replaceAll(RegExp(r'[^\w]'), '');
          
          // Check if word1 matches action and word2 matches document (with typos)
          if (_fuzzyMatch(word1, action) && _fuzzyMatch(word2, doc)) {
            return true;
          }
          
          // Also check for "un" or "una" between them
          if (i < words.length - 2) {
            final word3 = words[i + 2].replaceAll(RegExp(r'[^\w]'), '');
            if (_fuzzyMatch(word1, action) && 
                (words[i + 1] == 'un' || words[i + 1] == 'una' || words[i + 1] == 'a') &&
                _fuzzyMatch(word3, doc)) {
              return true;
            }
          }
        }
      }
    }

    // Also check for common patterns with typos in "documento"
    final documentoVariations = [
      'documento', 'documenro', 'documeto', 'documnto', 'docuemnto',
      'document', 'documet', 'documnt', 'docuemnt',
    ];

    for (final docVar in documentoVariations) {
      for (final action in actionKeywords) {
        final patterns = [
          '$action un $docVar',
          '$action $docVar',
          '$action me un $docVar',
        ];
        for (final pattern in patterns) {
          if (lowerMessage.contains(pattern)) return true;
        }
      }
    }

    return false;
  }


  /// Check if message contains reminder keywords
  bool _hasReminderKeywords(String messageText) {
    final String lowerMessage = messageText.toLowerCase();
    final List<String> reminderKeywords = [
      'reminder', 'remind me', 'set a reminder', 'create a reminder',
      'add a reminder', 'schedule a reminder', 'recordatorio', 'recordar',
      'agregar recordatorio', 'crear recordatorio', 'haz un recordatorio',
      'hazme un recordatorio', 'recuérdame', 'recuerda',
    ];
    return reminderKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// Check if reminder is related to current chat/document context
  bool _isReminderRelatedToContext(String messageText) {
    final String lowerMessage = messageText.toLowerCase();
    
    // Keywords that indicate the reminder is related to current context
    final List<String> contextKeywords = [
      // Document-related
      'documento', 'document', 'texto', 'text', 'escrito', 'escrit',
      'este documento', 'this document', 'el documento', 'the document',
      'revisar documento', 'review document', 'continuar documento', 'continue document',
      'trabajar en documento', 'work on document', 'editar documento', 'edit document',
      'editar ese documento', 'edit that document', 'editar el documento', 'edit the document',
      'ese documento', 'that document', 'el mismo documento', 'the same document',
      // Chat-related
      'esta conversación', 'this conversation', 'esta charla', 'this chat',
      'continuar conversación', 'continue conversation', 'revisar conversación', 'review conversation',
      // Generic context
      'esto', 'this', 'esté', 'este', 'esta', 'these', 'estos', 'estas',
      'ese', 'esa', 'eso', 'that', 'those',
      'aquí', 'here', 'ahora', 'now', 'continuar', 'continue', 'seguir', 'follow',
      'revisar', 'review', 'revisar esto', 'review this',
    ];
    
    // Check if message contains context keywords
    final bool hasContextKeywords = contextKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    // If in document mode or has a document, check for document-specific keywords
    if (isDocumentMode.value || currentDocumentId.value != null) {
      final List<String> documentContextKeywords = [
        'documento', 'document', 'texto', 'text', 'escrito',
        'revisar', 'review', 'continuar', 'continue', 'editar', 'edit',
        'trabajar', 'work', 'mejorar', 'improve', 'actualizar', 'update',
        'ese', 'esa', 'eso', 'that', 'el mismo', 'the same',
      ];
      final bool hasDocumentContext = documentContextKeywords.any((keyword) => lowerMessage.contains(keyword));
      
      // If has document context or context keywords, it's related
      // Also, if we're in document mode and the message mentions "editar" or "edit", it's definitely related
      final bool isEditRequest = lowerMessage.contains('editar') || lowerMessage.contains('edit');
      if (isEditRequest && (isDocumentMode.value || currentDocumentId.value != null)) {
        return true;
      }
      
      return hasDocumentContext || hasContextKeywords;
    }
    
    // If has context keywords, it's related to the chat
    if (hasContextKeywords) {
      return true;
    }
    
    // Check if the reminder title is very generic (likely not related)
    // Extract title to check if it's too generic
    final List<String> reminderKeywords = [
      'reminder', 'remind me', 'set a reminder', 'create a reminder',
      'add a reminder', 'schedule a reminder', 'recordatorio', 'recordar',
      'agregar recordatorio', 'crear recordatorio', 'haz un recordatorio',
    ];
    
    String title = messageText;
    for (final keyword in reminderKeywords) {
      final index = lowerMessage.indexOf(keyword);
      if (index != -1) {
        title = messageText.substring(index + keyword.length).trim();
        break;
      }
    }
    
    // Remove time/date words
    title = title.replaceAll(RegExp(r'\b(tomorrow|today|now|in|at|on|en|mañana|hoy|ahora)\b', caseSensitive: false), '').trim();
    title = title.replaceAll(RegExp(r'\d{1,2}:\d{2}'), '').trim();
    title = title.replaceAll(RegExp(r'\d{1,2}/\d{1,2}/\d{4}'), '').trim();
    title = title.replaceAll(RegExp(r'\d+\s+(minuto|minutos|minutes?|hora|horas|hours?|día|días|days?)'), '').trim();
    
    // If title is empty or too short after cleanup, it's likely not related
    if (title.isEmpty || title.length < 10) {
      return false;
    }
    
    // If title doesn't contain any context or document keywords, it's not related
    final String lowerTitle = title.toLowerCase();
    final bool titleHasContext = contextKeywords.any((keyword) => lowerTitle.contains(keyword));
    final bool titleHasDocumentKeywords = ['documento', 'document', 'texto', 'text', 'escrito', 'escrit', 'chat', 'conversación'].any((keyword) => lowerTitle.contains(keyword));
    
    // If title has context or document keywords, it's related
    return titleHasContext || titleHasDocumentKeywords;
  }

  /// Check if message is requesting to edit an existing document (not create new)
  bool _isEditingExistingDocument(String messageText) {
    final String lowerMessage = messageText.toLowerCase();
    
    // Keywords that indicate editing an existing document
    final List<String> editKeywords = [
      'editar', 'edit', 'modificar', 'modify', 'actualizar', 'update',
      'revisar', 'review', 'mejorar', 'improve', 'cambiar', 'change',
      'ese documento', 'that document', 'el documento', 'the document',
      'este documento', 'this document', 'el mismo documento', 'the same document',
    ];
    
    // If in document mode or has a document, and message contains edit keywords
    if ((isDocumentMode.value || currentDocumentId.value != null) &&
        editKeywords.any((keyword) => lowerMessage.contains(keyword))) {
      return true;
    }
    
    return false;
  }

  /// Get suggested reminder message based on current context
  String? _getSuggestedReminderMessage() {
    if (isDocumentMode.value || currentDocumentId.value != null) {
      return '''💡 Sugerencia de recordatorio:

Parece que quieres crear un recordatorio que no está relacionado con el documento actual.

¿Te gustaría crear un recordatorio para revisar o continuar trabajando en este documento?

Ejemplos:
- "Haz un recordatorio para revisar este documento en 1 hora"
- "Recuérdame continuar con el documento mañana"
- "Crea un recordatorio para editar el documento el lunes"''';
    } else if (hasMessages.value) {
      return '''💡 Sugerencia de recordatorio:

Parece que quieres crear un recordatorio que no está relacionado con esta conversación.

¿Te gustaría:
- Crear un recordatorio relacionado con esta conversación (ej: "Recuérdame continuar esta conversación mañana")
- Crear un documento y luego un recordatorio sobre él (ej: "Haz un recordatorio para crear un documento mañana")

Ejemplos:
- "Haz un recordatorio para continuar esta conversación en 2 horas"
- "Crea un recordatorio para hacer un documento sobre [tema] mañana"''';
    } else {
      return '''💡 Sugerencia de recordatorio:

Parece que quieres crear un recordatorio, pero no está claro sobre qué.

¿Te gustaría crear un recordatorio para crear un documento?

Ejemplo: "Haz un recordatorio para crear un documento sobre [tema] en 1 hora"''';
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

      // Add user message to the chat first (needed for both reminders and documents)
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

      // PRIORITY 1: Check for reminder request FIRST
      // This has higher priority than document creation
      // Allow reminders even in document mode or when document keywords are present
      final bool hasReminderKeywords = _hasReminderKeywords(messageText);
      if (hasReminderKeywords) {
        // Check if reminder is related to chat/document context
        final bool isReminderRelated = _isReminderRelatedToContext(messageText);
        
        if (!isReminderRelated) {
          // Reminder is not related to current context - show suggestion
          final String? suggestedReminder = _getSuggestedReminderMessage();
          
          final MessageLocal suggestionMessage = await ChatService.createAssistantMessage(
            conversationId: currentConversationId.value,
            text: suggestedReminder ?? '''💡 Sugerencia de recordatorio:

Parece que quieres crear un recordatorio, pero no está relacionado con esta conversación o documento.

¿Te gustaría crear un recordatorio para:
- ${isDocumentMode.value || currentDocumentId.value != null 
    ? 'Revisar o continuar trabajando en el documento actual' 
    : 'Crear un nuevo documento'}
- O puedes especificar que el recordatorio es sobre este chat/documento

Ejemplo: "Haz un recordatorio para revisar este documento en 1 hora"''',
          );
          messages.add(suggestionMessage);
          hasMessages.value = true;
          _scrollToBottom();

          // Don't get AI response - just show the suggestion message
          return; // Exit without creating reminder
        }
        
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

            // Add confirmation message to chat (single response, no AI response)
            final MessageLocal confirmationMessage = await ChatService.createAssistantMessage(
              conversationId: currentConversationId.value,
              text: '✅ Reminder created: "$reminderTitle" at ${_formatReminderDate(reminderDate)}. You will receive a notification in $timeUntilReminderText.',
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

            // IMPORTANT: If reminder is related to existing document, do NOT create a new document
            // Only create a new document if:
            // 1. The reminder is NOT related to an existing document
            // 2. AND the message explicitly requests creating a NEW document
            final bool isDocumentRequest = _isDocumentRequest(messageText);
            final bool hasExistingDocument = isDocumentMode.value || currentDocumentId.value != null;
            
            // Check if the document request is for creating a NEW document (not editing existing)
            final bool isNewDocumentRequest = isDocumentRequest && 
                !hasExistingDocument && 
                !_isEditingExistingDocument(messageText);
            
            if (isNewDocumentRequest) {
              // User wants both a reminder AND to create a NEW document
              // Create the document after the reminder
              debugPrint('User requested both reminder and NEW document creation');
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Activate document mode
              isDocumentMode.value = true;
              
              // Generate document
              await generateDocumentWithChecklist(messageText);
              return; // Exit early after creating document
            }

            // Don't get additional AI response - just the confirmation message
            return;
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
            // Continue with normal flow
            await Future.delayed(const Duration(milliseconds: 300));
            // Check if document should be created instead
            final bool isDocumentRequest = _isDocumentRequest(messageText);
            if (isDocumentRequest && !isDocumentMode.value) {
              isDocumentMode.value = true;
              await generateDocumentWithChecklist(messageText);
              return;
            }
            await _getAIResponse(messageText);
          }
          return; // Exit after handling reminder
        }
      }

      // PRIORITY 2: Check if message is requesting document creation
      // Only if no reminder was detected
      final bool isDocumentRequest = _isDocumentRequest(messageText);
      if (isDocumentMode.value || isDocumentRequest) {
        // If not already in document mode, activate it
        if (!isDocumentMode.value) {
          debugPrint('Document mode activated from message: $messageText');
          isDocumentMode.value = true;
        }

        // In document mode, generate document with checklist
        await generateDocumentWithChecklist(messageText);
        return; // Exit early - don't process as regular chat
      }

      // PRIORITY 3: Regular chat mode - get AI response
      await Future.delayed(const Duration(milliseconds: 300));
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
      
      // Check if stopped before processing response
      if (_isStopped) {
        debugPrint('Generation was stopped before processing response');
        return;
      }
      
      debugPrint(
        'Received AI response: ${aiResponse.substring(0, aiResponse.length > 100 ? 100 : aiResponse.length)}...',
      );

      // Validate the response
      if (aiResponse.isEmpty ||
          aiResponse.trim().isEmpty ||
          aiResponse == '0') {
        throw Exception('Invalid or empty response from AI');
      }

      // Check again before creating message
      if (_isStopped) {
        debugPrint('Generation was stopped before creating message');
        return;
      }

      final MessageLocal aiMessage = await ChatService.createAssistantMessage(
        conversationId: currentConversationId.value,
        text: aiResponse,
      );

      // Final check before adding to messages
      if (_isStopped) {
        debugPrint('Generation was stopped before adding message');
        return;
      }

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
      
      // Don't show error message if it was stopped by user
      if (_isStopped) {
        debugPrint('Generation was stopped, skipping error message');
      } else {
        // Add error message to chat
        final MessageLocal errorMessage = await ChatService.createSystemMessage(
          conversationId: currentConversationId.value,
          text: 'Sorry, I encountered an error. Please try again.',
        );

        messages.add(errorMessage);
        _scrollToBottom();
      }
    } finally {
      isTyping.value = false;
      // Don't reset _isStopped here if it was set by stopGeneration
      // It will be reset by stopGeneration after cleanup
      if (!_isStopped) {
        _isStopped = false;
      }
      _currentRequest = null;
      _currentHttpClient = null;
      _currentStreamSubscription = null;
      _currentGenerationCompleter = null;
    }
  }

  /// Stop current generation
  Future<void> stopGeneration() async {
    if (!isTyping.value && _currentGenerationCompleter == null) return;
    
    debugPrint('Stopping generation...');
    _isStopped = true;
    
    // Complete any pending generation with cancellation
    if (_currentGenerationCompleter != null && !_currentGenerationCompleter!.isCompleted) {
      _currentGenerationCompleter!.completeError('Generation stopped by user');
    }
    
    try {
      // Close current request if exists
      _currentRequest?.abort();
      _currentRequest?.close();
    } catch (e) {
      debugPrint('Error aborting request: $e');
    }
    
    try {
      // Close HTTP client if exists
      _currentHttpClient?.close(force: true);
    } catch (e) {
      debugPrint('Error closing HTTP client: $e');
    }
    
    // Reset typing state immediately
    isTyping.value = false;
    
    // Cancel stream subscription if exists
    try {
      _currentStreamSubscription?.cancel();
    } catch (e) {
      debugPrint('Error canceling stream subscription: $e');
    }
    
    // Reset state variables
    _currentRequest = null;
    _currentHttpClient = null;
    _currentStreamSubscription = null;
    _currentGenerationCompleter = null;
    
    // Add pause message to chat
    try {
      final MessageLocal pauseMessage = await ChatService.createSystemMessage(
        conversationId: currentConversationId.value,
        text: '⏸️ Respuesta pausada. Puedes continuar la conversación enviando un nuevo mensaje.',
      );
      messages.add(pauseMessage);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error creating pause message: $e');
    }
    
    // Reset stop flag after a delay to allow cleanup
    Future.delayed(const Duration(milliseconds: 100), () {
      _isStopped = false;
    });
  }

  /// Call OpenAI API
  Future<String> _callOpenAIAPI(List<Map<String, String>> messages) async {
    final Completer<String> generationCompleter = Completer<String>();
    _currentGenerationCompleter = generationCompleter;
    _isStopped = false;
    _currentRequest = null;
    _currentHttpClient = null;

    try {
      final HttpClient httpClient = HttpClient();
      _currentHttpClient = httpClient;

      // Check if API key is available
      if (openaiKey == null || openaiKey!.isEmpty) {
        throw Exception('OpenAI API key is not configured');
      }

      // Check if stopped before starting
      if (_isStopped) {
        throw Exception('Generation stopped by user');
      }

      debugPrint('Using OpenAI API key: ${openaiKey!.substring(0, 8)}...');
      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      
      _currentRequest = request;

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

      // Check if stopped before getting response
      if (_isStopped) {
        request.abort();
        throw Exception('Generation stopped by user');
      }

      // Get response with timeout and cancellation support
      HttpClientResponse? response;
      try {
        response = await request.close().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            if (_isStopped) {
              throw Exception('Generation stopped by user');
            }
            throw Exception('Request timeout after 30 seconds');
          },
        );
      } catch (e) {
        if (_isStopped) {
          throw Exception('Generation stopped by user');
        }
        rethrow;
      }

      // Check if stopped during response
      if (_isStopped) {
        try {
          response.detachSocket();
        } catch (e) {
          debugPrint('Error detaching socket: $e');
        }
        throw Exception('Generation stopped by user');
      }

      // Read response body with cancellation checks
      final StringBuffer responseBuffer = StringBuffer();
      final streamCompleter = Completer<void>();
      bool isStoppedDuringRead = false;
      
      _currentStreamSubscription = response.transform(utf8.decoder).listen(
        (data) {
          // Check if stopped during read
          if (_isStopped) {
            isStoppedDuringRead = true;
            _currentStreamSubscription?.cancel();
            if (!streamCompleter.isCompleted) {
              streamCompleter.completeError('Generation stopped by user');
            }
            return;
          }
          responseBuffer.write(data);
        },
        onDone: () {
          if (!streamCompleter.isCompleted && !_isStopped) {
            streamCompleter.complete();
          }
        },
        onError: (error) {
          if (!streamCompleter.isCompleted) {
            if (_isStopped) {
              streamCompleter.completeError('Generation stopped by user');
            } else {
              streamCompleter.completeError(error);
            }
          }
        },
        cancelOnError: true,
      );
      
      // Wait for stream to complete, but check for cancellation
      try {
        await streamCompleter.future;
      } catch (e) {
        if (_isStopped || isStoppedDuringRead) {
          _currentStreamSubscription?.cancel();
          throw Exception('Generation stopped by user');
        }
        rethrow;
      }
      
      // Cancel subscription if stopped
      if (_isStopped || isStoppedDuringRead) {
        _currentStreamSubscription?.cancel();
        throw Exception('Generation stopped by user');
      }

      // Check if stopped after reading response
      if (_isStopped) {
        throw Exception('Generation stopped by user');
      }

      final String responseBody = responseBuffer.toString();

      debugPrint('OpenAI API Response Status: ${response.statusCode}');
      debugPrint('OpenAI API Response Body: ${responseBody.length > 200 ? "${responseBody.substring(0, 200)}..." : responseBody}');

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

        // Check one more time before returning
        if (_isStopped) {
          throw Exception('Generation stopped by user');
        }

        generationCompleter.complete(content);
        return content;
      } else {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      if (_isStopped) {
        debugPrint('Generation stopped by user');
        if (!generationCompleter.isCompleted) {
          generationCompleter.completeError('Generation stopped');
        }
        throw Exception('Generation stopped');
      }
      debugPrint('Error parsing OpenAI response: $e');
      if (!generationCompleter.isCompleted) {
        generationCompleter.completeError(e);
      }
      rethrow;
    } finally {
      // Force cleanup of all resources
      try {
        if (_currentRequest != null) {
          _currentRequest!.abort();
          _currentRequest!.close();
        }
      } catch (e) {
        debugPrint('Error closing request: $e');
      }
      
      try {
        if (_currentHttpClient != null) {
          _currentHttpClient!.close(force: true);
        }
      } catch (e) {
        debugPrint('Error closing HTTP client: $e');
      }
      
      // Cancel stream subscription if still active
      try {
        _currentStreamSubscription?.cancel();
      } catch (e) {
        debugPrint('Error canceling stream subscription in finally: $e');
      }
      
      // Only reset state if not stopped by user
      // If stopped, stopGeneration will handle cleanup
      if (!_isStopped) {
        _currentRequest = null;
        _currentHttpClient = null;
        _currentStreamSubscription = null;
        _currentGenerationCompleter = null;
      }
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

      // Don't add user message here - it's already added in sendMessage()
      // The user message was already added before calling this function

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

      // Detect language for completion message
      final String detectedLanguage = _detectLanguage(userRequest);
      
      // Show completion message only after document is fully generated
      String completionMessage;
      if (detectedLanguage == 'spanish') {
        completionMessage = '''✅ ¡Documento generado exitosamente!

Tu documento está listo. Toca este mensaje para abrir el editor y ver tu documento.''';
      } else if (detectedLanguage == 'french') {
        completionMessage = '''✅ Document généré avec succès!

Votre document est prêt. Appuyez sur ce message pour ouvrir l'éditeur et voir votre document.''';
      } else if (detectedLanguage == 'german') {
        completionMessage = '''✅ Dokument erfolgreich erstellt!

Ihr Dokument ist bereit. Tippen Sie auf diese Nachricht, um den Editor zu öffnen und Ihr Dokument anzuzeigen.''';
      } else if (detectedLanguage == 'portuguese') {
        completionMessage = '''✅ Documento gerado com sucesso!

Seu documento está pronto. Toque nesta mensagem para abrir o editor e ver seu documento.''';
      } else if (detectedLanguage == 'italian') {
        completionMessage = '''✅ Documento generato con successo!

Il tuo documento è pronto. Tocca questo messaggio per aprire l'editor e visualizzare il tuo documento.''';
      } else {
        completionMessage = '''✅ Document generated successfully!

Your document is ready. Tap this message to open the editor and view your document.''';
      }
      
      final MessageLocal completedMessage =
          await ChatService.createAssistantMessage(
            conversationId: currentConversationId.value,
            text: completionMessage,
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

  /// Detect language from text message
  String _detectLanguage(String text) {
    final String lowerText = text.toLowerCase();
    
    // Spanish keywords
    final List<String> spanishKeywords = [
      'crear', 'crea', 'escribir', 'escribe', 'documento', 'texto',
      'hacer', 'haz', 'generar', 'genera', 'redactar', 'redacta',
      'elaborar', 'elabora', 'componer', 'compone', 'un', 'una',
      'para', 'con', 'sobre', 'del', 'de', 'la', 'las', 'los',
      'porque', 'que', 'cuando', 'donde', 'como', 'por qué',
    ];
    
    // French keywords
    final List<String> frenchKeywords = [
      'créer', 'écrire', 'document', 'texte', 'faire', 'générer',
      'rédiger', 'pour', 'avec', 'sur', 'de', 'le', 'la', 'les',
      'un', 'une', 'parce', 'que', 'quand', 'où', 'comment',
    ];
    
    // German keywords
    final List<String> germanKeywords = [
      'erstellen', 'schreiben', 'dokument', 'text', 'machen', 'generieren',
      'verfassen', 'für', 'mit', 'über', 'von', 'der', 'die', 'das',
      'ein', 'eine', 'weil', 'wann', 'wo', 'wie', 'warum',
    ];
    
    // Portuguese keywords
    final List<String> portugueseKeywords = [
      'criar', 'escrever', 'documento', 'texto', 'fazer', 'gerar',
      'redigir', 'para', 'com', 'sobre', 'do', 'da', 'dos', 'das',
      'um', 'uma', 'porque', 'que', 'quando', 'onde', 'como',
    ];
    
    // Italian keywords
    final List<String> italianKeywords = [
      'creare', 'scrivere', 'documento', 'testo', 'fare', 'generare',
      'redigere', 'per', 'con', 'su', 'del', 'della', 'dei', 'delle',
      'un', 'una', 'perché', 'che', 'quando', 'dove', 'come',
    ];
    
    // Count matches for each language
    int spanishCount = spanishKeywords.where((kw) => lowerText.contains(kw)).length;
    int frenchCount = frenchKeywords.where((kw) => lowerText.contains(kw)).length;
    int germanCount = germanKeywords.where((kw) => lowerText.contains(kw)).length;
    int portugueseCount = portugueseKeywords.where((kw) => lowerText.contains(kw)).length;
    int italianCount = italianKeywords.where((kw) => lowerText.contains(kw)).length;
    
    // Find the language with the highest match count
    final List<MapEntry<int, String>> languageCounts = [
      MapEntry(spanishCount, 'spanish'),
      MapEntry(frenchCount, 'french'),
      MapEntry(germanCount, 'german'),
      MapEntry(portugueseCount, 'portuguese'),
      MapEntry(italianCount, 'italian'),
    ];
    
    // Sort by count (descending) and get the highest
    languageCounts.sort((a, b) => b.key.compareTo(a.key));
    final int maxCount = languageCounts.first.key;
    
    // Default to English if no clear match (less than 2 matches)
    if (maxCount < 2) {
      return 'english'; // Default to English
    }
    
    return languageCounts.first.value;
  }

  /// Generate checklist for document creation using AI
  Future<String> _generateDocumentChecklist(String userRequest) async {
    if (openaiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    final HttpClient httpClient = HttpClient();
    try {
      debugPrint('Calling OpenAI to generate document checklist...');
      
      // Detect language from user request
      final String detectedLanguage = _detectLanguage(userRequest);
      debugPrint('Detected language for document checklist: $detectedLanguage');

      // Prepare system message for checklist generation
      // IMPORTANT: Do NOT apply any chat rules here - document generation should be independent
      final String systemPrompt = detectedLanguage == 'english'
          ? '''You are a helpful assistant that creates planning checklists for document creation.
          
IMPORTANT: When creating checklists for documents, ignore any chat rules or custom instructions. Focus ONLY on the document creation task.

When given a document request, create a brief checklist (4-6 items) showing the steps you'll take to create it.

Format your response as:
📋 Planning your document...

✓ [First step]
✓ [Second step]
✓ [Third step]
✓ [Fourth step]
⏳ Generating your document now...

Keep it concise, relevant, and focused on the specific document type requested. Do not add any extra text, greetings, or content beyond the checklist.'''
          : '''You are a helpful assistant that creates planning checklists for document creation.
          
IMPORTANT: When creating checklists for documents, ignore any chat rules or custom instructions. Focus ONLY on the document creation task.

CRITICAL: Respond in ${detectedLanguage == 'spanish' ? 'Spanish (Español)' : detectedLanguage == 'french' ? 'French (Français)' : detectedLanguage == 'german' ? 'German (Deutsch)' : detectedLanguage == 'portuguese' ? 'Portuguese (Português)' : detectedLanguage == 'italian' ? 'Italian (Italiano)' : 'the same language as the user'}. Use the same language that the user used in their request.

When given a document request, create a brief checklist (4-6 items) showing the steps you'll take to create it.

Format your response as:
📋 ${detectedLanguage == 'spanish' ? 'Planificando tu documento...' : detectedLanguage == 'french' ? 'Planification de votre document...' : detectedLanguage == 'german' ? 'Planung Ihres Dokuments...' : detectedLanguage == 'portuguese' ? 'Planejando seu documento...' : detectedLanguage == 'italian' ? 'Pianificazione del tuo documento...' : 'Planning your document...'}

✓ [First step]
✓ [Second step]
✓ [Third step]
✓ [Fourth step]
⏳ ${detectedLanguage == 'spanish' ? 'Generando tu documento ahora...' : detectedLanguage == 'french' ? 'Génération de votre document en cours...' : detectedLanguage == 'german' ? 'Generierung Ihres Dokuments...' : detectedLanguage == 'portuguese' ? 'Gerando seu documento agora...' : detectedLanguage == 'italian' ? 'Generazione del tuo documento...' : 'Generating your document now...'}

Keep it concise, relevant, and focused on the specific document type requested. Do not add any extra text, greetings, or content beyond the checklist. Respond entirely in ${detectedLanguage == 'spanish' ? 'Spanish' : detectedLanguage == 'french' ? 'French' : detectedLanguage == 'german' ? 'German' : detectedLanguage == 'portuguese' ? 'Portuguese' : detectedLanguage == 'italian' ? 'Italian' : 'English'}.''';

      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': systemPrompt,
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
      // Fallback checklist in detected language
      final String detectedLanguage = _detectLanguage(userRequest);
      if (detectedLanguage == 'spanish') {
        return '''📋 Planificando tu documento...

✓ Entendiendo tus requisitos
✓ Estructurando el contenido
✓ Preparando secciones
✓ Organizando información
⏳ Generando tu documento ahora...''';
      } else if (detectedLanguage == 'french') {
        return '''📋 Planification de votre document...

✓ Compréhension de vos exigences
✓ Structuration du contenu
✓ Préparation des sections
✓ Organisation de l'information
⏳ Génération de votre document en cours...''';
      } else if (detectedLanguage == 'german') {
        return '''📋 Planung Ihres Dokuments...

✓ Verständnis Ihrer Anforderungen
✓ Strukturierung des Inhalts
✓ Vorbereitung der Abschnitte
✓ Organisation der Informationen
⏳ Generierung Ihres Dokuments...''';
      } else if (detectedLanguage == 'portuguese') {
        return '''📋 Planejando seu documento...

✓ Entendendo seus requisitos
✓ Estruturando o conteúdo
✓ Preparando seções
✓ Organizando informações
⏳ Gerando seu documento agora...''';
      } else if (detectedLanguage == 'italian') {
        return '''📋 Pianificazione del tuo documento...

✓ Comprensione dei tuoi requisiti
✓ Strutturazione del contenuto
✓ Preparazione delle sezioni
✓ Organizzazione delle informazioni
⏳ Generazione del tuo documento...''';
      } else {
        return '''📋 Planning your document...

✓ Understanding your requirements
✓ Structuring the content
✓ Preparing sections
✓ Organizing information
⏳ Generating your document now...''';
      }
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
      // IMPORTANT: Do NOT apply any chat rules here - document generation should be independent
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content':
              '''You are a helpful document writing assistant. Create well-structured, professional documents based on user requests.
          
IMPORTANT: When creating documents, ignore any chat rules or custom instructions. Focus ONLY on creating the document requested by the user. Do not add any extra text, greetings, or content that was not requested in the document creation request.

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

Make it comprehensive and ready to use with proper markdown formatting. Only include the document content - no additional text, greetings, or rules.''',
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

  /// Open the document editor with version selection
  Future<void> openDocumentEditor() async {
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

      if (docId == null || docId.isEmpty) {
        // No document ID, open with current content
        if (document != null && document.isNotEmpty) {
          _openDocumentEditorWithContent(
            title: title ?? 'Document',
            content: document,
            documentId: null,
          );
        } else {
          _showErrorSnackbar('No document available to open');
        }
        return;
      }

      // Get saved version from conversation context
      final savedVersion = await _getSavedDocumentVersion();
      
      // Get all versions
      final versions = await DocumentService.getDocumentVersions(docId);
      final currentDoc = await DocumentService.getDocument(docId);
      
      debugPrint('Document versions found: ${versions.length}');
      debugPrint('Current document version: ${currentDoc?['version_number'] ?? 1}');
      
      // If there are versions or version number > 1, show selector
      final int currentVersion = currentDoc?['version_number'] as int? ?? 1;
      if (versions.isNotEmpty || currentVersion > 1) {
        debugPrint('Showing version selector dialog');
        await _showVersionSelector(
          docId: docId,
          title: title ?? 'Document',
          savedVersion: savedVersion,
          currentDoc: currentDoc,
          versions: versions,
        );
      } else {
        debugPrint('No versions found, opening document directly');
        // Only one version or no versions, open directly
        final content = currentDoc?['content'] as String? ?? document ?? '';
        _openDocumentEditorWithContent(
          title: title ?? 'Document',
          content: content,
          documentId: docId,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error opening document editor: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorSnackbar('Error opening document editor: $e');
    }
  }

  /// Get saved document version from conversation context
  Future<int?> _getSavedDocumentVersion() async {
    try {
      final conversation = await ChatService.getConversation(currentConversationId.value);
      if (conversation?.context == null) return null;
      
      final context = jsonDecode(conversation!.context!) as Map<String, dynamic>?;
      if (context == null) return null;
      
      final docInfo = context['document'] as Map<String, dynamic>?;
      if (docInfo == null) return null;
      
      return docInfo['version_number'] as int?;
    } catch (e) {
      debugPrint('Error getting saved document version: $e');
      return null;
    }
  }

  /// Save document version to conversation context
  Future<void> _saveDocumentVersion(String documentId, int versionNumber) async {
    try {
      final conversation = await ChatService.getConversation(currentConversationId.value);
      if (conversation == null) return;
      
      Map<String, dynamic> context = {};
      if (conversation.context != null) {
        try {
          context = jsonDecode(conversation.context!) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error parsing context: $e');
        }
      }
      
      context['document'] = {
        'document_id': documentId,
        'version_number': versionNumber,
      };
      
      await ChatService.updateConversationContext(
        currentConversationId.value,
        jsonEncode(context),
      );
    } catch (e) {
      debugPrint('Error saving document version: $e');
    }
  }

  /// Show version selector dialog
  Future<void> _showVersionSelector({
    required String docId,
    required String title,
    int? savedVersion,
    Map<String, dynamic>? currentDoc,
    required List<Map<String, dynamic>> versions,
  }) async {
    final currentVersion = currentDoc?['version_number'] as int? ?? 1;
    final currentContent = currentDoc?['content'] as String? ?? '';
    
    // Build list of versions (current + historical)
    final List<Map<String, dynamic>> allVersions = [];
    
    // Add current version
    allVersions.add({
      'version_number': currentVersion,
      'content': currentContent,
      'is_current': true,
      'created_at': currentDoc?['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      'change_summary': null,
    });
    
    // Add historical versions
    for (final version in versions) {
      allVersions.add({
        'version_number': version['version_number'] as int? ?? 0,
        'content': version['content'] as String? ?? '',
        'is_current': false,
        'created_at': version['created_at'] as String? ?? '',
        'change_summary': version['change_summary'] as String?,
      });
    }
    
    // Sort by version number descending
    allVersions.sort((a, b) => (b['version_number'] as int).compareTo(a['version_number'] as int));
    
    // Show dialog using GetX dialog
    final isDark = Get.theme.brightness == Brightness.dark;
    final selectedVersion = await Get.dialog<Map<String, dynamic>>(
      barrierDismissible: true,
      AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Select Document Version',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: allVersions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No versions found',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allVersions.length,
                    itemBuilder: (context, index) {
                      final version = allVersions[index];
                      final versionNum = version['version_number'] as int;
                      final isCurrent = version['is_current'] as bool;
                      final changeSummary = version['change_summary'] as String?;
                      final createdAt = version['created_at'] as String?;
                      
                      return ListTile(
                        title: Row(
                          children: [
                            Text(
                              'Version $versionNum',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (savedVersion != null && versionNum == savedVersion) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (createdAt != null)
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            if (changeSummary != null && changeSummary.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                changeSummary,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        onTap: () => Get.back(result: version),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        ),
    );
    
    if (selectedVersion != null) {
      final versionNum = selectedVersion['version_number'] as int;
      final content = selectedVersion['content'] as String? ?? '';
      
      // Save selected version to context
      await _saveDocumentVersion(docId, versionNum);
      
      // Open editor with selected version
      _openDocumentEditorWithContent(
        title: title,
        content: content,
        documentId: docId,
      );
    }
  }

  /// Open document editor with specific content
  void _openDocumentEditorWithContent({
    required String title,
    required String content,
    String? documentId,
  }) {
    Navigator.of(Get.context!).push(
      MaterialPageRoute(
        builder: (context) => DocumentEditor(
          documentTitle: title,
          documentContent: content,
          documentId: documentId,
          conversationId: currentConversationId.value,
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
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
          '  Content preview: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}',
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
          
          // Try to get document ID from conversation context
          if (conversation.context != null) {
            try {
              final context = jsonDecode(conversation.context!) as Map<String, dynamic>?;
              final docInfo = context?['document'] as Map<String, dynamic>?;
              if (docInfo != null) {
                final docId = docInfo['document_id'] as String?;
                if (docId != null && docId.isNotEmpty) {
                  currentDocumentId.value = docId;
                  
                  // Try to load the saved version
                  final savedVersion = docInfo['version_number'] as int?;
                  if (savedVersion != null) {
                    try {
                      final versions = await DocumentService.getDocumentVersions(docId);
                      final version = versions.firstWhere(
                        (v) => (v['version_number'] as int? ?? 0) == savedVersion,
                        orElse: () => {},
                      );
                      
                      if (version.isNotEmpty) {
                        final versionContent = version['content'] as String?;
                        if (versionContent != null && versionContent.isNotEmpty) {
                          generatedDocument.value = versionContent;
                        }
                      } else {
                        // If saved version not found, try to get current document
                        final currentDoc = await DocumentService.getDocument(docId);
                        if (currentDoc != null) {
                          final currentVersion = currentDoc['version_number'] as int? ?? 1;
                          if (currentVersion == savedVersion) {
                            final currentContent = currentDoc['content'] as String?;
                            if (currentContent != null && currentContent.isNotEmpty) {
                              generatedDocument.value = currentContent;
                            }
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('Error loading saved document version: $e');
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error parsing conversation context: $e');
            }
          }
          
          break; // Only need to restore the first document
        }
      }
      
      // Also check if there's a document ID in context but no document message
      if (currentDocumentId.value == null && conversation.context != null) {
        try {
          final context = jsonDecode(conversation.context!) as Map<String, dynamic>?;
          final docInfo = context?['document'] as Map<String, dynamic>?;
          if (docInfo != null) {
            final docId = docInfo['document_id'] as String?;
            if (docId != null && docId.isNotEmpty) {
              currentDocumentId.value = docId;
              isDocumentMode.value = true;
              
              // Try to load the document
              try {
                final doc = await DocumentService.getDocument(docId);
                if (doc != null) {
                  final savedVersion = docInfo['version_number'] as int?;
                  final currentVersion = doc['version_number'] as int? ?? 1;
                  
                  if (savedVersion != null && savedVersion != currentVersion) {
                    // Load the saved version
                    final versions = await DocumentService.getDocumentVersions(docId);
                    final version = versions.firstWhere(
                      (v) => (v['version_number'] as int? ?? 0) == savedVersion,
                      orElse: () => {},
                    );
                    
                    if (version.isNotEmpty) {
                      final versionContent = version['content'] as String?;
                      if (versionContent != null && versionContent.isNotEmpty) {
                        generatedDocument.value = versionContent;
                        documentTitle.value = doc['title'] as String? ?? conversation.title ?? 'Document';
                      }
                    }
                  } else {
                    // Load current version
                    final content = doc['content'] as String?;
                    if (content != null && content.isNotEmpty) {
                      generatedDocument.value = content;
                      documentTitle.value = doc['title'] as String? ?? conversation.title ?? 'Document';
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error loading document: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing conversation context for document: $e');
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
