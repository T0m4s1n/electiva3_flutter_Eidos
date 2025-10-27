import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/chat_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList>
    with SingleTickerProviderStateMixin {
  final ChatController chatController = Get.find<ChatController>();
  final NavigationController navController = Get.find<NavigationController>();
  final RxList<ConversationLocal> conversations = <ConversationLocal>[].obs;
  final RxBool isLoading = false.obs;
  final Set<String> _deletingIds = <String>{};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadConversations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      isLoading.value = true;
      final List<ConversationLocal> convs =
          await ChatService.getConversations();
      conversations.value = convs;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _startNewChat() async {
    try {
      // Use the controller's startNewChat method which handles everything
      await chatController.startNewChat();

      // Refresh conversations list
      await _loadConversations();
    } catch (e) {
      debugPrint('Error starting new chat: $e');
    }
  }

  Future<void> _openConversation(String conversationId) async {
    try {
      await chatController.loadConversation(conversationId);
      navController.showChat();
    } catch (e) {
      debugPrint('Error opening conversation: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      debugPrint('Deleting conversation: $conversationId');
      
      // Check if this is the currently active conversation
      final bool isCurrentConversation = 
          chatController.currentConversationId.value == conversationId;
      
      // Add to deleting set and trigger animation
      setState(() {
        _deletingIds.add(conversationId);
      });
      
      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Delete from database
      await ChatService.deleteConversation(conversationId);
      debugPrint('Conversation deleted from database');
      
      // Remove from deleting set
      setState(() {
        _deletingIds.remove(conversationId);
      });
      
      // Reload the conversations list
      await _loadConversations();
      
      // If this was the current conversation, clear the controller state and hide chat
      if (isCurrentConversation) {
        chatController.messages.clear();
        chatController.currentConversationId.value = '';
        chatController.conversationTitle.value = 'New Chat';
        chatController.hasMessages.value = false;
        navController.hideChat();
        debugPrint('Cleared current conversation state');
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      // Remove from deleting set on error
      setState(() {
        _deletingIds.remove(conversationId);
      });
      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to delete conversation',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (conversations.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _buildConversationCard(conversation);
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Documents.json SVG from Lottie
          SizedBox(
            width: 200,
            height: 200,
            child: Lottie.asset(
              'assets/fonts/svgs/documents.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to begin',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startNewChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black87),
              ),
              child: const Text(
                'Start New Chat',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(ConversationLocal conversation) {
    final bool isDeleting = _deletingIds.contains(conversation.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(conversation.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
        ),
        onDismissed: (direction) {
          _deleteConversation(conversation.id);
        },
        child: AnimatedOpacity(
          opacity: isDeleting ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: isDeleting
                ? Matrix4.translationValues(-MediaQuery.of(context).size.width, 0, 0)
                : null,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black87),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                conversation.title ?? 'Untitled Chat',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conversation.summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conversation.summary!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(conversation.lastMessageAt ?? conversation.updatedAt),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'delete':
                      _deleteConversation(conversation.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, color: Colors.black87),
              ),
              onTap: () => _openConversation(conversation.id),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final DateTime dateTime = DateTime.parse(isoString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}
