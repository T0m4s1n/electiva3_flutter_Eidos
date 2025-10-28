import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';

class DocumentEditor extends StatefulWidget {
  final String documentTitle;
  final String documentContent;

  const DocumentEditor({
    super.key,
    required this.documentTitle,
    required this.documentContent,
  });

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  late TextEditingController _contentController;
  bool _hasUnsavedChanges = false;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.documentContent);
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        elevation: 0,
        leading: IconButton(
          icon: Container(
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
          onPressed: () {
            if (_hasUnsavedChanges) {
              _showSaveDialog();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          widget.documentTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          // Toggle preview/edit mode
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit : Icons.preview,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              setState(() {
                _isPreviewMode = !_isPreviewMode;
              });
            },
            tooltip: _isPreviewMode ? 'Edit mode' : 'Preview mode',
          ),
          if (_hasUnsavedChanges)
            IconButton(
              icon: Icon(
                Icons.save,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: _saveDocument,
              tooltip: 'Save document',
            ),
          IconButton(
            icon: Icon(
              Icons.share,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _shareDocument,
            tooltip: 'Share document',
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          if (!_isPreviewMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildToolbarButton(Icons.format_bold, 'Bold', () => _insertMarkdown('**', '**')),
                  const SizedBox(width: 8),
                  _buildToolbarButton(Icons.format_italic, 'Italic', () => _insertMarkdown('*', '*')),
                  const SizedBox(width: 8),
                  _buildToolbarButton(Icons.code, 'Code', () => _insertMarkdown('`', '`')),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  const SizedBox(width: 16),
                  _buildToolbarButton(Icons.title, 'H2', () => _insertMarkdown('## ', '')),
                  const SizedBox(width: 8),
                  _buildToolbarButton(Icons.title, 'H3', () => _insertMarkdown('### ', '')),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  const SizedBox(width: 16),
                  _buildToolbarButton(Icons.format_list_bulleted, 'Bullets', () => _insertMarkdown('- ', '')),
                ],
              ),
            ),
          // Document content
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0D0D0D) : Colors.grey[100],
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isPreviewMode
                          ? _buildPreview()
                          : _buildEditor(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: Theme.of(context).iconTheme.color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final TextSelection selection = _contentController.selection;
    final String text = _contentController.text;
    
    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      // Has valid selection
      final String selectedText = selection.textInside(text);
      final String newText = '$prefix$selectedText$suffix';
      
      _contentController.value = TextEditingValue(
        text: text.replaceRange(
          selection.start.clamp(0, text.length),
          selection.end.clamp(0, text.length),
          newText,
        ),
        selection: TextSelection.collapsed(
          offset: (selection.start + prefix.length + selectedText.length + suffix.length).clamp(0, text.length + prefix.length + suffix.length),
        ),
      );
    } else if (selection.start >= 0 && selection.start <= text.length) {
      // Valid cursor position, insert at cursor
      final String newText = text.substring(0, selection.start.clamp(0, text.length)) + 
                            prefix + suffix + 
                            text.substring(selection.start.clamp(0, text.length));
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (selection.start + prefix.length).clamp(0, newText.length),
        ),
      );
    } else {
      // Invalid cursor position, append at the end
      final String newText = text + prefix + suffix;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - suffix.length,
        ),
      );
    }
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      child: TextField(
        controller: _contentController,
        maxLines: null,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start typing your document...',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      child: MarkdownBody(
        data: _contentController.text.isEmpty ? 'No content to preview' : _contentController.text,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            height: 1.6,
            color: Colors.black87,
          ),
          h1: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          h2: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          h3: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          h4: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          strong: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          em: const TextStyle(
            fontFamily: 'Poppins',
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
          code: TextStyle(
            fontFamily: 'Courier',
            fontSize: 13,
            backgroundColor: Colors.grey[200],
            color: Colors.black87,
          ),
          blockquote: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
          ),
          listBullet: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  void _saveDocument() {
    // Save functionality
    setState(() {
      _hasUnsavedChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saved'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareDocument() {
    // Share functionality
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Document',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to clipboard'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _contentController.text));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Share via email'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        content: const Text(
          'You have unsaved changes. Do you want to save them before leaving?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () {
              _saveDocument();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}

