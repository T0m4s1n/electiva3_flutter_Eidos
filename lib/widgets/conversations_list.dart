import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/chat_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_database.dart';
import 'animated_icon_background.dart';
import '../services/translation_service.dart';

class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ChatController chatController = Get.find<ChatController>();
  final NavigationController navController = Get.find<NavigationController>();
  final RxList<ConversationLocal> conversations = <ConversationLocal>[].obs;
  final RxBool isLoading = false.obs;
  final Set<String> _deletingIds = <String>{};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Initialize database and load conversations
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    try {
      isLoading.value = true;
      
      // Initialize the database first
      await ChatDatabase.instance;
      debugPrint('Database initialized successfully');
      
      // Load conversations
      await _loadConversations();
    } catch (e) {
      debugPrint('Error initializing database: $e');
      conversations.clear();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload conversations when app comes back to foreground
      _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    try {
      debugPrint('Loading conversations from database...');
      final List<ConversationLocal> convs =
          await ChatService.getConversations();
      
      debugPrint('Fetched ${convs.length} conversations from database');
      
      // Clear the list first to ensure UI updates
      conversations.clear();
      
      // Add the new conversations
      conversations.addAll(convs);
      
      debugPrint('Updated conversations list. Current count: ${conversations.length}');
      
      // Force UI update by reassigning
      conversations.refresh();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      conversations.clear();
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
      // Ask HomePage header to close if open by toggling showChat again in next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Nothing else needed; HomePage listens to showChatView and will rebuild
      });
    } catch (e) {
      debugPrint('Error opening conversation: $e');
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      debugPrint('=== Starting delete process for conversation: $conversationId ===');
      
      // Check if this is the currently active conversation
      final bool isCurrentConversation = 
          chatController.currentConversationId.value == conversationId;
      debugPrint('Is current conversation: $isCurrentConversation');
      
      // Add to deleting set and trigger animation
      setState(() {
        _deletingIds.add(conversationId);
      });
      debugPrint('Added to deleting set');
      
      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Delete from database using local storage
      debugPrint('Calling ChatService.deleteConversation');
      await ChatService.deleteConversation(conversationId);
      debugPrint('Successfully deleted conversation from database');
      
      // Remove from deleting set
      setState(() {
        _deletingIds.remove(conversationId);
      });
      debugPrint('Removed from deleting set');
      
      // Wait a bit to ensure database transaction is complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Reload the conversations list from local storage
      debugPrint('Reloading conversations list');
      await _loadConversations();
      debugPrint('Conversations list reloaded. Current count: ${conversations.length}');
      
      // If this was the current conversation, clear the controller state and hide chat
      if (isCurrentConversation) {
        debugPrint('Clearing current conversation from controller');
        chatController.messages.clear();
        chatController.currentConversationId.value = '';
        chatController.conversationTitle.value = 'New Chat';
        chatController.hasMessages.value = false;
        
        // Hide chat view to show the conversations list
        navController.hideChat();
        debugPrint('Cleared current conversation state and hid chat');
      }
      
      debugPrint('=== Delete process completed successfully ===');
    } catch (e, stackTrace) {
      debugPrint('=== Error deleting conversation: $e ===');
      debugPrint('Stack trace: $stackTrace');
      
      // Remove from deleting set on error
      setState(() {
        _deletingIds.remove(conversationId);
      });
      
      // Show error to user
      Get.snackbar(
        TranslationService.translate('error'),
        TranslationService.translate('failed_to_delete_conversation'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
  }

  Future<void> _archiveConversation(String conversationId, bool archive) async {
    try {
      await ChatService.toggleConversationArchive(conversationId, archive);
      await _loadConversations();
      if (archive && navController.showChatView.value && chatController.currentConversationId.value == conversationId) {
        navController.hideChat();
      }
    } catch (e) {
      debugPrint('Error archiving conversation: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Filter out archived conversations
      final visibleConversations = conversations.where((c) => !c.isArchived).toList();
      final bool hasVisibleConversations = visibleConversations.isNotEmpty;
      
      return Stack(
        children: [
          // Animated background
          const Positioned.fill(
            child: DocumentIconBackground(),
          ),
          
          // Main content
          if (isLoading.value)
            const Center(child: CircularProgressIndicator())
          else if (!hasVisibleConversations)
            _buildEmptyState()
          else
            RefreshIndicator(
              displacement: 80,
              onRefresh: () async {
                // Navigate to archived chats when user pulls down from top
                Get.toNamed('/archive');
                // Delay to satisfy RefreshIndicator's future
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: visibleConversations.length,
                itemBuilder: (context, index) {
                  final conversation = visibleConversations[index];
                  return _buildConversationCard(conversation);
                },
              ),
            ),
          
        ],
      );
    });
  }

  Widget _buildEmptyState() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Documents.json SVG from Lottie
          Container(
            width: 200,
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Lottie.asset(
              'assets/fonts/svgs/documents.json',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              TranslationService.translate('no_conversations_yet'),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Text(
              TranslationService.translate('start_chat_prompt'),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startNewChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              child:                   Obx(
                    () => Text(
                      TranslationService.translate('start_new_chat'),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.black87 : Colors.white,
                      ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.black87,
              ),
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
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model chip
                  if ((conversation.model ?? '').isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.grey[600]! : Colors.black87,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.memory,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            conversation.model!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (conversation.summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conversation.summary!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
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
                    case 'archive':
                      _archiveConversation(conversation.id, true);
                      break;
                    case 'unarchive':
                      _archiveConversation(conversation.id, false);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: conversation.isArchived ? 'unarchive' : 'archive',
                    child: Row(
                      children: [
                        Icon(
                          conversation.isArchived ? Icons.unarchive : Icons.archive_outlined,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: 8),
                        Text(conversation.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
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
                child: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).iconTheme.color,
                ),
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
