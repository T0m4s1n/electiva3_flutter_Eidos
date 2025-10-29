import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import '../controllers/chat_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/animated_icon_background.dart';

class ChatArchivePage extends StatefulWidget {
  const ChatArchivePage({super.key});

  @override
  State<ChatArchivePage> createState() => _ChatArchivePageState();
}

class _ChatArchivePageState extends State<ChatArchivePage> {
  List<ConversationLocal> _archived = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    setState(() => _loading = true);
    try {
      final all = await ChatService.getConversations();
      setState(() {
        _archived = all.where((c) => c.isArchived).toList()
          ..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unarchive(String conversationId) async {
    await ChatService.toggleConversationArchive(conversationId, false);
    await _loadArchived();
  }

  Future<void> _delete(String conversationId) async {
    await ChatService.deleteConversation(conversationId);
    await _loadArchived();
  }

  Future<void> _openConversation(String conversationId) async {
    final chatController = Get.find<ChatController>();
    final navController = Get.find<NavigationController>();
    await chatController.loadConversation(conversationId);
    navController.showChat();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Archived Chats', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Theme.of(context).cardTheme.color,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArchived),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatIconBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_archived.isEmpty)
            Center(
              child: Text(
                'No archived chats',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _loadArchived,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _archived.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final c = _archived[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        (c.title ?? 'Untitled Chat'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                      ),
                      subtitle: c.lastMessageAt != null
                          ? Text(
                              c.lastMessageAt!,
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                            )
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'unarchive':
                              _unarchive(c.id);
                              break;
                            case 'delete':
                              _delete(c.id);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'unarchive',
                            child: Row(
                              children: [
                                Icon(Icons.unarchive),
                                SizedBox(width: 8),
                                Text('Unarchive'),
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
                        child: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color),
                      ),
                      onTap: () => _openConversation(c.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}



