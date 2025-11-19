import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/chat_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_database.dart';
import '../services/auth_service.dart';
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
  final AuthController authController = Get.find<AuthController>();
  final RxList<ConversationLocal> conversations = <ConversationLocal>[].obs;
  final RxBool isLoading = false.obs;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Listen to auth state changes to reload conversations when logged in
    _listenToAuthChanges();
    // Initialize database and load conversations
    _initializeAndLoad();
  }

  void _listenToAuthChanges() {
    // Listen to login state changes
    ever(authController.isLoggedIn, (bool isLoggedIn) {
      if (isLoggedIn) {
        // When user logs in, reload conversations after a delay
        // to allow sync to complete (non-blocking)
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            // Use microtask to defer heavy database operations
            Future.microtask(() => _loadConversations());
          }
        });
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    try {
      isLoading.value = true;
      
      // Initialize the database first (non-blocking)
      // Use Future.microtask to defer heavy operations
      await Future.microtask(() async {
      await ChatDatabase.instance;
      debugPrint('Database initialized successfully');
      
        // Load conversations after database is ready
      await _loadConversations();
      });
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
      
      // If user is logged in, sync with Supabase first (non-blocking)
      if (authController.isLoggedIn.value) {
        final currentUser = AuthService.currentUser;
        final userId = currentUser?.id ?? '';
        if (userId.isNotEmpty) {
          // Sync with Supabase in background (non-blocking)
          Future.microtask(() async {
            try {
              debugPrint('Syncing with Supabase for user: $userId');
              await AuthService.manualSync();
              debugPrint('Sync completed, reloading conversations...');
              
              // Reload conversations after sync completes
              if (mounted) {
                await _loadConversationsFromLocal();
              }
            } catch (e) {
              debugPrint('Error syncing with Supabase: $e');
              // Continue to load local conversations even if sync fails
              if (mounted) {
                await _loadConversationsFromLocal();
              }
            }
          });
          
          // Load local conversations immediately (don't wait for sync)
          await _loadConversationsFromLocal();
        } else {
          // No user ID, just load local conversations
          await _loadConversationsFromLocal();
        }
      } else {
        // Not logged in, just load local conversations
        await _loadConversationsFromLocal();
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        conversations.clear();
      }
    }
  }

  Future<void> _loadConversationsFromLocal() async {
    try {
      // Perform database query in a microtask to avoid blocking UI
      final List<ConversationLocal> convs = await Future.microtask(() async {
        return await ChatService.getConversations();
      });
      
      debugPrint('Fetched ${convs.length} conversations from database');
      
      // Batch UI updates to avoid excessive rebuilds
      if (mounted) {
        // Clear and add in one operation to minimize rebuilds
      conversations.clear();
      conversations.addAll(convs);
        // Only refresh once after all updates
        conversations.refresh();
      }
      
      debugPrint('Updated conversations list. Current count: ${conversations.length}');
    } catch (e) {
      debugPrint('Error loading conversations from local: $e');
      if (mounted) {
      conversations.clear();
      }
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
    ConversationLocal? deletedConversation;
    try {
      debugPrint('=== Starting delete process for conversation: $conversationId ===');
      
      // Check if this is the currently active conversation
      final bool isCurrentConversation = 
          chatController.currentConversationId.value == conversationId;
      debugPrint('Is current conversation: $isCurrentConversation');
      
      // Store the conversation in case we need to restore it on error
      deletedConversation = conversations.firstWhereOrNull((c) => c.id == conversationId);
      
      // Delete from database using local storage (non-blocking)
      // Use compute isolate for heavy database operations to avoid blocking UI
      debugPrint('Calling ChatService.deleteConversation');
      await ChatService.deleteConversation(conversationId);
      debugPrint('Successfully deleted conversation from database');
      
      // Ensure the conversation is removed from the observable list if not already removed
      // This handles cases where deletion happens via popup menu (not swipe)
      if (mounted && conversations.any((c) => c.id == conversationId)) {
        conversations.removeWhere((c) => c.id == conversationId);
        Future.microtask(() {
          if (mounted) {
            conversations.refresh();
          }
        });
      }
      
      // Reload conversations from database to ensure consistency
      // Use microtask to defer to avoid blocking UI
      Future.microtask(() async {
        if (mounted) {
          await _loadConversationsFromLocal();
        }
      });
      
      debugPrint('Conversation deleted. Current count: ${conversations.length}');
      
      // If this was the current conversation, clear the controller state and hide chat
      if (isCurrentConversation) {
        debugPrint('Clearing current conversation from controller');
        // Use microtask to defer UI updates
        Future.microtask(() {
          if (mounted) {
        chatController.messages.clear();
        chatController.currentConversationId.value = '';
        chatController.conversationTitle.value = 'New Chat';
        chatController.hasMessages.value = false;
        
        // Hide chat view to show the conversations list
        navController.hideChat();
        debugPrint('Cleared current conversation state and hid chat');
          }
        });
      }
      
      debugPrint('=== Delete process completed successfully ===');
    } catch (e, stackTrace) {
      debugPrint('=== Error deleting conversation: $e ===');
      debugPrint('Stack trace: $stackTrace');
      
      // If deletion failed and we have the conversation, restore it to the list
      if (deletedConversation != null && !conversations.any((c) => c.id == conversationId)) {
        debugPrint('Restoring conversation to list due to deletion failure');
        // Use microtask to defer UI update
        Future.microtask(() {
          if (mounted) {
            conversations.add(deletedConversation!);
            conversations.refresh();
          }
        });
      }
      
      // Show error to user (non-blocking)
      Future.microtask(() {
        if (mounted) {
      Get.snackbar(
            TranslationService.translate('error'),
            TranslationService.translate('failed_to_delete_conversation'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    }
      });
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
                // Add cacheExtent to improve performance
                cacheExtent: 500,
                // Use key to help Flutter optimize rebuilds
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
          // Documents.json SVG from Lottie with colorful gradient background
          Container(
            width: 200,
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: isDark
                  ? [
                      Colors.blue[400]!.withValues(alpha: 0.2),
                      Colors.purple[400]!.withValues(alpha: 0.1),
                      Colors.transparent,
                    ]
                  : [
                      Colors.blue[100]!.withValues(alpha: 0.5),
                      Colors.purple[100]!.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                stops: const [0.0, 0.5, 1.0],
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Obx(
                    () => Text(
                      TranslationService.translate('start_new_chat'),
                      style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(ConversationLocal conversation) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(conversation.id),
        direction: DismissDirection.endToStart,
        // Add resistance to prevent accidental dismissals
        resizeDuration: const Duration(milliseconds: 300),
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
          // Immediately remove from list to prevent crash
          // The widget is already dismissed, so we need to update the list
          final conversationToDelete = conversation;
          final conversationId = conversationToDelete.id;
          
          // Remove from list immediately (synchronous - required by Dismissible)
          // But wrap in microtask to defer to next frame to avoid blocking UI
          conversations.removeWhere((c) => c.id == conversationId);
          
          // Schedule refresh for next frame to avoid blocking current frame
          Future.microtask(() {
            if (mounted) {
              conversations.refresh();
            }
          });
          
          // Perform the actual deletion asynchronously (non-blocking)
          // Use Future.delayed to ensure UI update happens first
          Future.delayed(const Duration(milliseconds: 50), () {
            _deleteConversation(conversationId);
          });
        },
            child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [
                        const Color(0xFF1E1E1E),
                        const Color(0xFF2A2A2A),
                      ]
                    : [
                        Colors.white,
                        Colors.grey[50]!,
                      ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.black87,
                  width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black87,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
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
                  // Model chip with gradient
                  if ((conversation.model ?? '').isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [Colors.blue[800]!, Colors.purple[800]!]
                            : [Colors.blue[100]!, Colors.purple[100]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.blue[400]!.withValues(alpha: 0.3) : Colors.blue[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.memory,
                            size: 14,
                            color: isDark ? Colors.blue[200] : Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                            conversation.model!,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.blue[200] : Colors.blue[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
