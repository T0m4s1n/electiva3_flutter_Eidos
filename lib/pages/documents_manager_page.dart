import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/chat_database.dart';
import '../widgets/document_editor.dart';
import '../widgets/animated_icon_background.dart';

class DocumentsManagerPage extends StatefulWidget {
  const DocumentsManagerPage({super.key});

  @override
  State<DocumentsManagerPage> createState() => _DocumentsManagerPageState();
}

class _DocumentsManagerPageState extends State<DocumentsManagerPage> {
  List<Map<String, Object?>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final Database db = await ChatDatabase.instance;
      final results = await db.query('documents', orderBy: 'updated_at DESC');
      setState(() {
        _docs = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Documents', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Theme.of(context).cardTheme.color,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: DocumentIconBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_docs.isEmpty)
            Center(
              child: Text(
                'No documents yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          else
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                    final doc = _docs[index];
                    final title = (doc['title'] as String?) ?? 'Untitled';
                    final updatedAt = (doc['updated_at'] as String?) ?? '';
                    final content = (doc['content'] as String?) ?? '';
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          updatedAt,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DocumentEditor(
                                documentTitle: title,
                                documentContent: content,
                                documentId: doc['id'] as String?,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: _docs.length,
            ),
        ],
      ),
    );
  }
}



