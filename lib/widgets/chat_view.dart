import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import 'message_widgets.dart';
import 'animated_icon_background.dart';

class ChatView extends StatefulWidget {
  final VoidCallback? onBack;

  const ChatView({super.key, this.onBack});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with TickerProviderStateMixin {
  late AnimationController _ideaController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ChatController chatController;
  int _initialMessageCount = 0;

  @override
  void initState() {
    super.initState();

    // Get chat controller
    chatController = Get.find<ChatController>();

    // Track initial message count (messages that were loaded, not generated now)
    _initialMessageCount = chatController.messages.length;

    // Initialize chat if no conversation is active
    if (chatController.currentConversationId.value.isEmpty) {
      chatController.initializeChat();
    }

    // Controller for the idea animation (play once)
    _ideaController = AnimationController(vsync: this);

    // Controller for fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start fade in animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Always show pyramid background
          const Positioned.fill(
            child: ChatPyramidBackground(),
          ),
          
          // Main content
          Column(
            children: [
              // Header with back button and title
              _buildHeader(),

              // Main chat content
              Expanded(
                child: Obx(() {
                  if (chatController.hasMessages.value) {
                    return _buildChatMessages();
                  } else {
                    // Show new chat view for any chat without messages
                    return _buildEmptyState();
                  }
                }),
              ),

              // Chat input
              Obx(
                () => ChatInput(
                  controller: chatController.messageController,
                  onSend: chatController.sendMessage,
                  onStop: chatController.stopGeneration,
                  isLoading: chatController.isLoading.value,
                  isTyping: chatController.isTyping.value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.black87,
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Theme.of(context).iconTheme.color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() => Text(
              chatController.conversationTitle.value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return Obx(() {
      // Filter out document-type messages from display
      final List<MessageLocal> displayMessages = chatController.messages
          .where((msg) {
            final Map<String, dynamic> content = msg.content;
            return content['type'] != 'document';
          })
          .toList();
      
      return ListView.builder(
        controller: chatController.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: displayMessages.length,
        itemBuilder: (context, index) {
          final message = displayMessages[index];
          
          // Check if this is a completion message with document ready (all languages)
          final String messageText = _getMessageText(message);
          final bool isDocumentReady = messageText.contains('Document generated successfully') ||
                                      messageText.contains('Your document is ready') ||
                                      messageText.contains('Documento generado exitosamente') ||
                                      messageText.contains('Tu documento está listo') ||
                                      messageText.contains('Document généré avec succès') ||
                                      messageText.contains('Votre document est prêt') ||
                                      messageText.contains('Dokument erfolgreich erstellt') ||
                                      messageText.contains('Ihr Dokument ist bereit') ||
                                      messageText.contains('Documento gerado com sucesso') ||
                                      messageText.contains('Seu documento está pronto') ||
                                      messageText.contains('Documento generato con successo') ||
                                      messageText.contains('Il tuo documento è pronto') ||
                                      messageText.contains('Toca este mensaje') ||
                                      messageText.contains('Tap this message') ||
                                      messageText.contains('Appuyez sur ce message') ||
                                      messageText.contains('Tippen Sie auf diese Nachricht') ||
                                      messageText.contains('Toque nesta mensagem') ||
                                      messageText.contains('Tocca questo messaggio');
          
          // Only animate messages that were added AFTER initial load
          // Messages at index < _initialMessageCount were loaded from database
          final bool isNewMessage = index >= _initialMessageCount;
          final bool isLastMessage = index == displayMessages.length - 1;
          
          // Only animate if: 
          // 1. Message was added in this session (not loaded)
          // 2. It's the last message
          // 3. It's an assistant message
          final bool shouldAnimate = isNewMessage && 
                                    isLastMessage && 
                                    message.role == 'assistant';
          
          return MessageBubble(
            message: message,
            isUser: message.role == 'user',
            animateTyping: shouldAnimate,
            onTap: isDocumentReady ? chatController.openDocumentEditor : null,
          );
        },
      );
    });
  }

  String _getMessageText(MessageLocal message) {
    final dynamic content = message.content;
    if (content is Map<String, dynamic>) {
      return content['text'] as String? ?? content.toString();
    }
    return content.toString();
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Idea animation (plays in loop)
            Center(
              child: Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(90),
                ),
                child: Lottie.asset(
                  'assets/fonts/svgs/idea.json',
                  controller: _ideaController,
                  fit: BoxFit.contain,
                  repeat: true, // Loop the animation
                  onLoaded: (composition) {
                    // Set the duration and play the animation in a loop
                    _ideaController.duration = composition.duration;
                    _ideaController.repeat();
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Welcome message
            Text(
              'Welcome to your new chat!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Start typing your message below to begin our conversation',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // Create Document button
            _buildDocumentButton(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentButton() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => chatController.handleDocumentCreation(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.black87,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Creating Animation
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Lottie.asset(
                'assets/fonts/svgs/creating.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create Document',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get AI-powered help to write and edit documents',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Arrow icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward,
                color: isDark ? Colors.black87 : Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
