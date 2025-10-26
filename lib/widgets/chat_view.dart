import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import 'message_widgets.dart';

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

  @override
  void initState() {
    super.initState();

    // Get chat controller
    chatController = Get.find<ChatController>();

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
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header with back button and title
            _buildHeader(),

            // Main chat content
            Expanded(
              child: Obx(() {
                if (chatController.hasMessages.value) {
                  return _buildChatMessages();
                } else {
                  return _buildEmptyState();
                }
              }),
            ),

            // Chat input
            Obx(
              () => ChatInput(
                controller: chatController.messageController,
                onSend: chatController.sendMessage,
                isLoading: chatController.isLoading.value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(
              () => Text(
                chatController.conversationTitle.value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          // New chat button
          GestureDetector(
            onTap: chatController.startNewChat,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: const Icon(Icons.add, color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    return Obx(() {
      return ListView.builder(
        controller: chatController.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount:
            chatController.messages.length +
            (chatController.isTyping.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < chatController.messages.length) {
            final message = chatController.messages[index];
            return MessageBubble(
              message: message,
              isUser: message.role == 'user',
            );
          } else {
            return const TypingIndicator();
          }
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: IntrinsicHeight(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Idea animation (plays in loop)
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
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

                const SizedBox(height: 30),

                // Welcome message
                const Center(
                  child: Text(
                    'Welcome to your new chat!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'Start typing your message below to begin our conversation',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Quick actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.lightbulb_outline,
                        text: 'Ideas',
                        onTap: () => chatController.handleQuickAction('Ideas'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.code,
                        text: 'Code',
                        onTap: () => chatController.handleQuickAction('Code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.description_outlined,
                        text: 'Write',
                        onTap: () => chatController.handleQuickAction('Write'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black87),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
