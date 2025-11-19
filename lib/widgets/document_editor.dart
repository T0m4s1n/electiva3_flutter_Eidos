import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:printing/printing.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/document_service.dart';
import '../services/chat_service.dart';
import '../services/hive_storage_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents an AI suggestion (addition or deletion)
class AISuggestion {
  final int start;
  final int end;
  final String? replacement; // null for deletion, text for addition/replacement
  final bool isDeletion;
  final String originalText;

  AISuggestion({
    required this.start,
    required this.end,
    this.replacement,
    required this.isDeletion,
    required this.originalText,
  });
}

class DocumentEditor extends StatefulWidget {
  final String documentTitle;
  final String documentContent;
  final String? documentId;
  final String? conversationId;

  const DocumentEditor({
    super.key,
    required this.documentTitle,
    required this.documentContent,
    this.documentId,
    this.conversationId,
  });

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> with SingleTickerProviderStateMixin {
  late TextEditingController _contentController;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _currentDocumentId; // Track document ID for versioning
  final ScrollController _editScrollController = ScrollController();
  final FocusNode _contentFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _versions = [];
  bool _loadingVersions = false;
  bool _showAIAssistant = false;
  bool _showFormattedPreview = true;
  final TextEditingController _aiPromptController = TextEditingController();
  bool _aiProcessing = false;
  String? get openaiKey => dotenv.env['OPENAI_KEY'];
  List<AISuggestion> _aiSuggestions = [];
  String? _originalContentBeforeAI;
  late AnimationController _aiPanelAnimationController;
  late Animation<Offset> _aiPanelSlideAnimation;
  late Animation<double> _aiPanelFadeAnimation;
  Timer? _markdownPreviewTimer;
  DateTime? _lastSaveTime; // Track when document was last saved
  String _savedContent = ''; // Track the content that was last saved

  @override
  void initState() {
    super.initState();
    try {
      _contentController = TextEditingController(text: widget.documentContent);
      _currentDocumentId = widget.documentId; // Initialize with provided documentId
      _savedContent = widget.documentContent; // Initialize saved content
      _contentController.addListener(_onContentChanged);
      
      // Initialize AI panel animation
      _aiPanelAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      _aiPanelSlideAnimation = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _aiPanelAnimationController,
        curve: Curves.easeOut,
      ));
      _aiPanelFadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _aiPanelAnimationController,
        curve: Curves.easeOut,
      ));
      
      // Load versions if document already exists
      if (_currentDocumentId != null) {
        _loadVersions();
      }
    } catch (e) {
      debugPrint('Error initializing document editor: $e');
    }
  }

  void _onContentChanged() {
    // Check if content actually changed from saved content
    final currentContent = _contentController.text;
    final hasActualChanges = currentContent != _savedContent;
    
    if (hasActualChanges && !_hasChanges && mounted) {
      setState(() => _hasChanges = true);
    } else if (!hasActualChanges && _hasChanges && mounted) {
      // Content was reverted to saved state
      setState(() => _hasChanges = false);
    }
    
    // Hide markdown preview while typing
    if (mounted && _showFormattedPreview) {
      setState(() {
        _showFormattedPreview = false;
      });
    }
    
    // Reset timer - show markdown after 5 seconds of inactivity
    _markdownPreviewTimer?.cancel();
    _markdownPreviewTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _aiSuggestions.isEmpty) {
        setState(() {
          _showFormattedPreview = true;
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      _markdownPreviewTimer?.cancel();
      _contentController.removeListener(_onContentChanged);
      _contentController.dispose();
      _aiPromptController.dispose();
      _editScrollController.dispose();
      _contentFocusNode.dispose();
      _aiPanelAnimationController.dispose();
    } catch (e) {
      debugPrint('Error disposing document editor: $e');
    }
    super.dispose();
  }

  Future<void> _saveDocument() async {
    if (_isSaving || !mounted) return;
    
    // Check if there are any changes
    if (!_hasChanges) {
      Get.snackbar('Info', 'There are no changes to save',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.blue[100], colorText: Colors.blue[800],
        duration: const Duration(seconds: 2));
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      final String content = _contentController.text;
      if (content.isEmpty) {
        if (mounted) {
          Get.snackbar('Error', 'Document content cannot be empty',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
        }
        return;
      }
      try {
        // Generate change summary using AI if this is an update
        String? changeSummary;
        if (_currentDocumentId != null && openaiKey != null) {
          try {
            // Get old content for comparison
            final oldDoc = await DocumentService.getDocument(_currentDocumentId!);
            final oldContent = oldDoc?['content'] as String? ?? '';
            
            if (oldContent.isNotEmpty && oldContent != content) {
              changeSummary = await _generateVersionChangeSummary(oldContent, content);
            }
          } catch (e) {
            debugPrint('Error generating change summary: $e');
            // Continue without summary if AI fails
          }
        }
        
        // Always create a version when saving
        // If documentId exists, it will create a new version
        // If not, it will create a new document with version 1
        final String savedDocId = await DocumentService.saveDocument(
          conversationId: widget.conversationId ?? '',
          title: widget.documentTitle, // Use original title, not editable
          content: content,
          documentId: _currentDocumentId, // Use tracked documentId (null for new documents)
          changeSummary: changeSummary,
        );
        
        // Update tracked documentId after first save
        if (_currentDocumentId == null && savedDocId.isNotEmpty) {
          _currentDocumentId = savedDocId;
        }
        
        // Get the new version number and save it to conversation context
        if (_currentDocumentId != null && widget.conversationId != null) {
          try {
            final savedDoc = await DocumentService.getDocument(_currentDocumentId!);
            if (savedDoc != null) {
              final versionNumber = savedDoc['version_number'] as int? ?? 1;
              await _saveDocumentVersionToChat(_currentDocumentId!, versionNumber);
            }
          } catch (e) {
            debugPrint('Error saving document version to chat: $e');
          }
        }
        
        // Reload versions after save
        if (_currentDocumentId != null) {
          _loadVersions();
        }
        
        // Generate and upload PDF to Supabase
        if (savedDocId.isNotEmpty) {
          try {
            await _generateAndUploadPDF(savedDocId, content);
          } catch (e) {
            debugPrint('Error uploading PDF to Supabase: $e');
            // Don't fail the save if PDF upload fails
          }
        }
        
        if (mounted) {
          setState(() {
            _hasChanges = false;
            _lastSaveTime = DateTime.now();
            _savedContent = content; // Update saved content
          });
          Get.snackbar('Success', 'Document saved successfully',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800],
            duration: const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error saving document: $e');
        if (mounted) {
          Get.snackbar('Error', 'Failed to save document: ${e.toString()}',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800],
            duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('Unexpected error in _saveDocument: $e');
      if (mounted) {
        Get.snackbar('Error', 'An unexpected error occurred',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _onWillPop() async {
    // Check if there are actual changes from saved content
    final currentContent = _contentController.text;
    final hasActualChanges = currentContent != _savedContent;
    
    // If cursor is present but no actual changes and there was a recent save, don't show dialog
    final bool hasFocus = _contentFocusNode.hasFocus;
    final bool hasRecentSave = _lastSaveTime != null && 
        DateTime.now().difference(_lastSaveTime!).inSeconds < 30; // Consider "recent" as within 30 seconds
    
    if (!hasActualChanges) {
      // No actual changes, allow pop
      return true;
    }
    
    // If cursor is present but there was a recent save and content matches saved content, allow pop
    if (hasFocus && hasRecentSave && !hasActualChanges) {
      return true;
    }
    
    // Show dialog only if there are actual changes
    final bool? shouldPop = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unsaved Changes', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: const Text('You have unsaved changes. Do you want to save before leaving?', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(fontFamily: 'Poppins', color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins'))),
          ElevatedButton(onPressed: () async { Navigator.pop(context, false); await _saveDocument(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
            child: const Text('Save', style: TextStyle(fontFamily: 'Poppins'))),
        ]));
    return shouldPop ?? false;
  }



  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export as DOCX', style: TextStyle(fontFamily: 'Poppins')),
              onTap: () {
                Navigator.pop(context);
                _exportToDOCX();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Generate PDF from markdown content
  Future<Uint8List> _generatePDFBytes(String markdownText) async {
    final pdf = pw.Document();
    
    // Convert markdown to plain text for PDF (simplified)
    final lines = markdownText.split('\n');
    final List<pw.Widget> widgets = [];
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 8));
        continue;
      }
      
      if (line.startsWith('# ')) {
        widgets.add(pw.Text(line.substring(2), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)));
      } else if (line.startsWith('## ')) {
        widgets.add(pw.Text(line.substring(3), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
      } else if (line.startsWith('### ')) {
        widgets.add(pw.Text(line.substring(4), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)));
      } else if (line.startsWith('- ')) {
        widgets.add(pw.Text('• ${line.substring(2)}', style: pw.TextStyle(fontSize: 14)));
      } else if (line.startsWith('**') && line.endsWith('**')) {
        widgets.add(pw.Text(line.substring(2, line.length - 2), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      } else {
        widgets.add(pw.Text(line, style: pw.TextStyle(fontSize: 14)));
      }
      widgets.add(pw.SizedBox(height: 4));
    }
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(widget.documentTitle, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              ...widgets,
            ],
          );
        },
      ),
    );
    
    return await pdf.save();
  }

  /// Generate and upload PDF to Supabase
  Future<void> _generateAndUploadPDF(String documentId, String content) async {
    try {
      final pdfBytes = await _generatePDFBytes(content);
      final fileName = '$documentId.pdf';
      
      debugPrint('Generating PDF for document: $documentId, size: ${pdfBytes.length} bytes');
      
      // Upload to Supabase storage
      await _uploadFileToSupabase(pdfBytes, fileName, 'application/pdf', documentId: documentId);
      
      debugPrint('PDF uploaded successfully to Supabase for document: $documentId');
    } catch (e) {
      debugPrint('Error generating/uploading PDF for document $documentId: $e');
      rethrow;
    }
  }

  Future<void> _exportToPDF() async {
    try {
      if (_currentDocumentId == null || _currentDocumentId!.isEmpty) {
        if (mounted) {
          Get.snackbar('Error', 'Please save the document first before exporting',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
        }
        return;
      }
      
      // Download PDF from Supabase
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final supabase = Supabase.instance.client;
      final path = '$userId/documents/$_currentDocumentId.pdf';
      
      Uint8List? pdfBytes;
      
      try {
        // Try to download the PDF
        pdfBytes = await supabase.storage
            .from('documents')
            .download(path);
      } catch (e) {
        // If download fails (404 or other error), generate PDF now
        debugPrint('PDF not found in Supabase, generating now: $e');
        pdfBytes = null;
      }
      
      if (pdfBytes == null || pdfBytes.isEmpty) {
        // If PDF doesn't exist, generate it now
        if (mounted) {
          Get.snackbar('Info', 'Generating PDF...',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.blue[100], colorText: Colors.blue[800]);
        }
        
        // Generate PDF bytes directly (don't upload, just use for export)
        pdfBytes = await _generatePDFBytes(_contentController.text);
        
        // Also upload to Supabase for future use
        try {
          await _generateAndUploadPDF(_currentDocumentId!, _contentController.text);
        } catch (uploadError) {
          debugPrint('Warning: Failed to upload PDF to Supabase: $uploadError');
          // Continue anyway, we have the PDF bytes
        }
      }
      
      // Save locally and share
      await _saveAndSharePDF(pdfBytes);
      
      if (mounted) {
        Get.snackbar('Success', 'PDF exported successfully',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800]);
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (mounted) {
        Get.snackbar('Error', 'Failed to export PDF: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      }
    }
  }

  /// Save PDF locally and share it
  Future<void> _saveAndSharePDF(Uint8List pdfBytes) async {
    final fileName = '${widget.documentTitle.replaceAll(' ', '_')}.pdf';
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    
    // Share the file using printing package
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
    );
    
    debugPrint('PDF saved to: ${file.path}');
  }

  Future<void> _exportToDOCX() async {
    try {
      // For DOCX, we'll create a simple text file that can be opened in Word
      // Note: Full DOCX support requires a more complex library
      final markdownText = _contentController.text;
      final fileName = '${widget.documentTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.docx';
      
      // Convert markdown to plain text (simplified)
      final plainText = md.markdownToHtml(markdownText);
      
      // Create a simple HTML-based document (Word can open HTML)
      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${widget.documentTitle}</title>
</head>
<body>
  <h1>${widget.documentTitle}</h1>
  $plainText
</body>
</html>
''';
      
      final bytes = utf8.encode(htmlContent);
      
      // Upload to Supabase storage
      await _uploadFileToSupabase(bytes, fileName, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      
      // Also save locally
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        Get.snackbar('Success', 'Document exported and saved to Supabase',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800]);
      }
    } catch (e) {
      debugPrint('Error exporting to DOCX: $e');
      if (mounted) {
        Get.snackbar('Error', 'Failed to export document: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      }
    }
  }

  Future<void> _uploadFileToSupabase(List<int> bytes, String fileName, String mimeType, {String? documentId}) async {
    try {
      final String? userId = AuthService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final supabase = Supabase.instance.client;
      // If documentId is provided, use documents folder, otherwise use exports folder
      final path = documentId != null 
          ? '$userId/documents/$fileName'
          : '$userId/exports/$fileName';
      
      debugPrint('Uploading file to Supabase: bucket=documents, path=$path, size=${bytes.length} bytes');
      
      await supabase.storage.from('documents').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );
      
      debugPrint('File uploaded successfully to Supabase: $path');
    } catch (e) {
      final String? userId = AuthService.currentUser?.id;
      final errorPath = documentId != null 
          ? '$userId/documents/$fileName'
          : '$userId/exports/$fileName';
      debugPrint('Error uploading to Supabase (path: $errorPath, error: $e)');
      rethrow;
    }
  }

  Future<void> _loadVersions() async {
    if (_currentDocumentId == null) return;
    
    setState(() => _loadingVersions = true);
    try {
      final versions = await DocumentService.getDocumentVersions(_currentDocumentId!);
      if (mounted) {
        setState(() {
          _versions = versions;
          _loadingVersions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading versions: $e');
      if (mounted) {
        setState(() => _loadingVersions = false);
      }
    }
  }

  void _showVersionsSidebar() {
    if (_currentDocumentId == null) {
      Get.snackbar('Info', 'Save the document first to see versions',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.blue[100], colorText: Colors.blue[800]);
      return;
    }
    
    _loadVersions();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _restoreVersion(Map<String, dynamic> version) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore Version', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to restore version ${version['version_number']}? This will replace your current content.',
          style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
            child: const Text('Restore', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final String content = version['content'] as String? ?? '';
      _contentController.text = content;
      setState(() => _hasChanges = true);
      _scaffoldKey.currentState?.closeEndDrawer();
      Get.snackbar('Success', 'Version restored',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800]);
    }
  }

  String _formatVersionDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
        }
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  /// Save document version to conversation context
  Future<void> _saveDocumentVersionToChat(String documentId, int versionNumber) async {
    if (widget.conversationId == null || widget.conversationId!.isEmpty) return;
    
    try {
      final conversation = await ChatService.getConversation(widget.conversationId!);
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
        widget.conversationId!,
        jsonEncode(context),
      );
    } catch (e) {
      debugPrint('Error saving document version to chat: $e');
    }
  }

  void _insertMarkdown(String prefix, [String? suffix]) {
    try {
      final TextSelection selection = _contentController.selection;
      if (selection.isValid) {
        final String text = _contentController.text;
        final String selectedText = selection.textInside(text);
        final String newText = prefix + selectedText + (suffix ?? prefix);
        _contentController.value = TextEditingValue(
          text: text.replaceRange(selection.start, selection.end, newText),
          selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + (suffix?.length ?? prefix.length)));
      } else {
        final int cursorPosition = _contentController.selection.baseOffset;
        final String text = _contentController.text;
        final int safeCursorPosition = cursorPosition.clamp(0, text.length);
        final String newText = text.substring(0, safeCursorPosition) + prefix + (suffix ?? '') + text.substring(safeCursorPosition);
        _contentController.value = TextEditingValue(
          text: newText, selection: TextSelection.collapsed(offset: safeCursorPosition + prefix.length));
      }
      _contentFocusNode.requestFocus();
    } catch (e) {
      debugPrint('Error inserting markdown: $e');
    }
  }

  Widget _buildToolbarButton({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return Tooltip(message: tooltip, child: IconButton(icon: Icon(icon, size: 20), onPressed: onPressed, tooltip: tooltip));
  }

  Widget _buildToolbar(bool isDark) {
    return Container(height: 50,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!))),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildToolbarButton(icon: Icons.format_bold, tooltip: 'Bold', onPressed: () => _insertMarkdown('**', '**')),
          _buildToolbarButton(icon: Icons.format_italic, tooltip: 'Italic', onPressed: () => _insertMarkdown('*', '*')),
          _buildToolbarButton(icon: Icons.format_underlined, tooltip: 'Underline', onPressed: () => _insertMarkdown('<u>', '</u>')),
          const VerticalDivider(width: 1),
          _buildToolbarButton(icon: Icons.title, tooltip: 'Heading 1', onPressed: () => _insertMarkdown('# ')),
          _buildToolbarButton(icon: Icons.format_size, tooltip: 'Heading 2', onPressed: () => _insertMarkdown('## ')),
          _buildToolbarButton(icon: Icons.text_fields, tooltip: 'Heading 3', onPressed: () => _insertMarkdown('### ')),
          const VerticalDivider(width: 1),
          _buildToolbarButton(icon: Icons.format_list_bulleted, tooltip: 'Bullet List', onPressed: () => _insertMarkdown('- ')),
          _buildToolbarButton(icon: Icons.format_list_numbered, tooltip: 'Numbered List', onPressed: () => _insertMarkdown('1. ')),
          _buildToolbarButton(icon: Icons.format_quote, tooltip: 'Quote', onPressed: () => _insertMarkdown('> ')),
          const VerticalDivider(width: 1),
          _buildToolbarButton(icon: Icons.code, tooltip: 'Code', onPressed: () => _insertMarkdown('`', '`')),
          _buildToolbarButton(icon: Icons.link, tooltip: 'Link', onPressed: () => _insertMarkdown('[', '](url)')),
          _buildToolbarButton(icon: Icons.image, tooltip: 'Image', onPressed: () => _insertMarkdown('![alt text](', ')')),
          const VerticalDivider(width: 1),
          _buildToolbarButton(icon: Icons.horizontal_rule, tooltip: 'Horizontal Rule', onPressed: () => _insertMarkdown('\n---\n')),
          const VerticalDivider(width: 1),
          Tooltip(
            message: _showFormattedPreview ? 'Show raw text' : 'Show formatted preview',
            child: IconButton(
              icon: Icon(_showFormattedPreview ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() => _showFormattedPreview = !_showFormattedPreview);
              },
            ),
          ),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(canPop: !_hasChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && _hasChanges) {
          final bool shouldPop = await _onWillPop();
          if (shouldPop && mounted && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () async { final bool canPop = await _onWillPop(); if (canPop && mounted && context.mounted) Navigator.of(context).pop(); }),
          title: Text(widget.documentTitle,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: Icon(_showAIAssistant ? Icons.smart_toy : Icons.smart_toy_outlined),
              tooltip: 'AI Assistant',
              onPressed: () {
                setState(() {
                  _showAIAssistant = !_showAIAssistant;
                });
              },
            ),
            if (_currentDocumentId != null)
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'View Versions',
                onPressed: _showVersionsSidebar,
              ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Document',
              onPressed: _showExportMenu,
            ),
            if (_aiSuggestions.isNotEmpty)
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.auto_awesome),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${_aiSuggestions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'AI Suggestions',
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            IconButton(
              icon: _isSaving 
                ? const SizedBox(
                    width: 20, 
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                    )
                  )
                : const Icon(Icons.save), 
              tooltip: 'Save Document', 
              onPressed: _isSaving ? null : _saveDocument
            ),
          ]),
        drawer: _buildAISuggestionsDrawer(isDark),
        endDrawer: _buildVersionsDrawer(isDark),
        body: SafeArea(child: Column(children: [
          _buildToolbar(isDark),
          Expanded(child: _buildWysiwygEditor(isDark)),
          if (_showAIAssistant) _buildAIAssistantPanel(isDark),
        ]))));
  }

  /// Build WYSIWYG editor that shows formatted markdown while editing
  Widget _buildWysiwygEditor(bool isDark) {
    return _MarkdownTextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      scrollController: _editScrollController,
      isDark: isDark,
      showFormattedPreview: _showFormattedPreview && _aiSuggestions.isEmpty,
      aiSuggestions: _aiSuggestions,
      onAcceptSuggestion: _acceptSuggestion,
      onDeclineSuggestion: _declineSuggestion,
      onAcceptAll: _acceptAllSuggestions,
      onDeclineAll: _declineAllSuggestions,
    );
  }

  /// Generate a brief summary of changes between document versions
  Future<String?> _generateVersionChangeSummary(String oldContent, String newContent) async {
    if (openaiKey == null) return null;
    
    try {
      final HttpClient httpClient = HttpClient();
      
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': '''You are a helpful assistant that creates brief summaries of document changes. 
Generate a concise summary (maximum 2-3 sentences) describing the main differences between two versions of a document.
Focus on what was added, removed, or modified. Keep it brief and informative.''',
        },
        {
          'role': 'user',
          'content': '''Compare these two document versions and provide a brief summary of changes:

OLD VERSION:
$oldContent

NEW VERSION:
$newContent

Provide a concise summary of the main changes:''',
        },
      ];

      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $openaiKey');

      final Map<String, dynamic> requestBody = {
        'model': 'gpt-4o-mini',
        'messages': messages,
        'max_tokens': 150,
        'temperature': 0.5,
      };

      request.write(jsonEncode(requestBody));

      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      final String responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        final Map<String, dynamic> firstChoice = responseData['choices'][0];
        final Map<String, dynamic> message = firstChoice['message'];
        final String? summary = message['content'] as String?;
        
        return summary?.trim();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error generating version change summary: $e');
      return null;
    }
  }

  Future<void> _processAIRequest(String prompt) async {
    if (openaiKey == null) {
      Get.snackbar('Error', 'OpenAI API key not configured',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      return;
    }

    if (prompt.trim().isEmpty) return;

    setState(() {
      _aiProcessing = true;
      _showFormattedPreview = false; // Hide markdown when AI is processing
    });

    try {
      final HttpClient httpClient = HttpClient();
      
      // Remove the "/" from the prompt if it's at the start
      String cleanPrompt = prompt.trim();
      if (cleanPrompt.startsWith('/')) {
        cleanPrompt = cleanPrompt.substring(1).trim();
      }

      // Store original content before AI processing
      _originalContentBeforeAI = _contentController.text;

      // Build messages for OpenAI with document context
      final List<Map<String, String>> messages = [
        {
          'role': 'system',
          'content': '''You are a helpful AI assistant that helps edit and improve documents. The user is working on a document and needs your assistance.

Current document content:
${_contentController.text}

IMPORTANT: 
- You can suggest edits, improvements, or directly modify the document content
- If the user asks you to edit the document, provide the complete updated document content
- Return ONLY the modified document content, without explanations or markdown code blocks
- Focus on the user's request while maintaining document quality
- Make minimal, focused changes based on the user's request''',
        },
        {
          'role': 'user',
          'content': cleanPrompt,
        },
      ];

      final HttpClientRequest request = await httpClient.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $openaiKey');
      request.headers.set('User-Agent', 'Eidos-Chat-App/1.0');

      final Map<String, dynamic> requestBody = {
        'model': 'gpt-4o-mini',
        'messages': messages,
        'max_tokens': HiveStorageService.loadMaxTokens(),
        'temperature': 0.7,
        'top_p': 1.0,
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

        if (responseData['choices'] == null || responseData['choices'].isEmpty) {
          throw Exception('No choices in OpenAI response');
        }

        final Map<String, dynamic> firstChoice = responseData['choices'][0];
        final Map<String, dynamic> message = firstChoice['message'];
        final String? content = message['content'] as String?;

        if (content == null || content.isEmpty) {
          throw Exception('Empty response from OpenAI');
        }

        // Extract document content and calculate diff
        final String? suggestedContent = _extractDocumentContent(content);
        if (suggestedContent != null && _originalContentBeforeAI != null) {
          // Calculate diff and show inline suggestions
          _calculateAndShowSuggestions(_originalContentBeforeAI!, suggestedContent);
        } else {
          // Just a suggestion or explanation
          Get.snackbar('AI Suggestion', content,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue[100],
            colorText: Colors.blue[800],
            duration: const Duration(seconds: 5),
          );
        }
      } else {
        throw Exception('OpenAI API error: ${response.statusCode} - $responseBody');
      }

      httpClient.close();
    } catch (e) {
      debugPrint('Error processing AI request: $e');
      if (mounted) {
        Get.snackbar('Error', 'Failed to process AI request: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      }
    } finally {
      if (mounted) {
        setState(() => _aiProcessing = false);
      }
    }
  }


  String? _extractDocumentContent(String aiResponse) {
    // Try to extract document content from markdown code blocks
    final codeBlockRegex = RegExp(r'```(?:markdown)?\s*\n(.*?)\n```', dotAll: true);
    final match = codeBlockRegex.firstMatch(aiResponse);
    if (match != null) {
      return match.group(1);
    }
    
    // If no code block, check if the entire response looks like a document
    if (aiResponse.contains('##') || aiResponse.length > 200) {
      // Remove any explanation text before the document content
      final lines = aiResponse.split('\n');
      final documentStart = lines.indexWhere((line) => 
        line.trim().startsWith('#') || 
        (line.trim().isNotEmpty && !line.trim().startsWith('Here') && !line.trim().startsWith('I\'ve'))
      );
      if (documentStart >= 0) {
        return lines.sublist(documentStart).join('\n');
      }
      return aiResponse;
    }
    
    return null;
  }

  /// Calculate diff between original and suggested content
  void _calculateAndShowSuggestions(String original, String suggested) {
    final List<AISuggestion> suggestions = [];
    
    // Simple diff algorithm - find differences
    final originalLines = original.split('\n');
    final suggestedLines = suggested.split('\n');
    
    // Use a simple line-by-line comparison
    int origIndex = 0;
    int suggIndex = 0;
    int currentPos = 0;
    
    while (origIndex < originalLines.length || suggIndex < suggestedLines.length) {
      if (origIndex >= originalLines.length) {
        // Addition
        final line = suggestedLines[suggIndex];
        suggestions.add(AISuggestion(
          start: currentPos,
          end: currentPos,
          replacement: line + (suggIndex < suggestedLines.length - 1 ? '\n' : ''),
          isDeletion: false,
          originalText: '',
        ));
        currentPos += line.length + 1;
        suggIndex++;
      } else if (suggIndex >= suggestedLines.length) {
        // Deletion
        final line = originalLines[origIndex];
        suggestions.add(AISuggestion(
          start: currentPos,
          end: currentPos + line.length,
          replacement: null,
          isDeletion: true,
          originalText: line,
        ));
        currentPos += line.length + 1;
        origIndex++;
      } else if (originalLines[origIndex] == suggestedLines[suggIndex]) {
        // Same line, move forward
        currentPos += originalLines[origIndex].length + 1;
        origIndex++;
        suggIndex++;
      } else {
        // Different lines - check if it's a modification
        final origLine = originalLines[origIndex];
        final suggLine = suggestedLines[suggIndex];
        
        // Check if it's a replacement
        if (origLine.trim().isNotEmpty && suggLine.trim().isNotEmpty) {
          suggestions.add(AISuggestion(
            start: currentPos,
            end: currentPos + origLine.length,
            replacement: suggLine + (suggIndex < suggestedLines.length - 1 ? '\n' : ''),
            isDeletion: false,
            originalText: origLine,
          ));
        } else if (origLine.trim().isNotEmpty) {
          // Deletion
          suggestions.add(AISuggestion(
            start: currentPos,
            end: currentPos + origLine.length,
            replacement: null,
            isDeletion: true,
            originalText: origLine,
          ));
        } else {
          // Addition
          suggestions.add(AISuggestion(
            start: currentPos,
            end: currentPos,
            replacement: suggLine + (suggIndex < suggestedLines.length - 1 ? '\n' : ''),
            isDeletion: false,
            originalText: '',
          ));
        }
        
        currentPos += origLine.length + 1;
        origIndex++;
        suggIndex++;
      }
    }
    
    if (suggestions.isNotEmpty) {
      setState(() {
        _aiSuggestions = suggestions;
        _showFormattedPreview = false; // Hide markdown when AI suggestions are active
      });
      // Open drawer automatically when suggestions are available
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _aiSuggestions.isNotEmpty) {
            _scaffoldKey.currentState?.openDrawer();
          }
        });
      }
    } else {
      // No differences found, apply directly
      _contentController.text = suggested;
      setState(() => _hasChanges = true);
      Get.snackbar('Success', 'Document updated with AI suggestions',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800]);
    }
  }

  void _acceptSuggestion(AISuggestion suggestion) {
    final text = _contentController.text;
    if (suggestion.isDeletion) {
      // Remove the text
      final newText = text.substring(0, suggestion.start) + text.substring(suggestion.end);
      _contentController.text = newText;
      // Adjust other suggestions
      _adjustSuggestionsAfterEdit(suggestion.start, suggestion.end - suggestion.start, 0);
    } else {
      // Insert or replace
      final newText = text.substring(0, suggestion.start) + 
                     (suggestion.replacement ?? '') + 
                     text.substring(suggestion.end);
      _contentController.text = newText;
      // Adjust other suggestions
      final lengthDiff = (suggestion.replacement?.length ?? 0) - (suggestion.end - suggestion.start);
      _adjustSuggestionsAfterEdit(suggestion.start, suggestion.end - suggestion.start, lengthDiff);
    }
    
    // Remove accepted suggestion
    setState(() {
      _aiSuggestions.remove(suggestion);
      // Show markdown again if no more suggestions
      if (_aiSuggestions.isEmpty) {
        _showFormattedPreview = true;
      }
    });
    
    setState(() => _hasChanges = true);
  }

  void _acceptAllSuggestions() {
    if (_aiSuggestions.isEmpty) return;
    
    try {
      // Apply all suggestions in reverse order to maintain positions
      final sortedSuggestions = List<AISuggestion>.from(_aiSuggestions)
        ..sort((a, b) => b.start.compareTo(a.start));
      
      String text = _contentController.text;
      
      for (final suggestion in sortedSuggestions) {
        // Calculate current positions accounting for previous edits
        final currentStart = suggestion.start;
        final currentEnd = suggestion.end;
        
        // Validate indices are within bounds
        if (currentStart < 0 || currentEnd < currentStart || currentEnd > text.length) {
          debugPrint('Invalid suggestion indices: start=$currentStart, end=$currentEnd, textLength=${text.length}');
          continue; // Skip invalid suggestions
        }
        
        try {
          if (suggestion.isDeletion) {
            // Delete the text from start to end
            text = text.substring(0, currentStart) + text.substring(currentEnd);
          } else {
            // Replace with new text
            final replacement = suggestion.replacement ?? '';
            text = text.substring(0, currentStart) + 
                   replacement + 
                   text.substring(currentEnd);
          }
        } catch (e) {
          debugPrint('Error applying suggestion: $e');
          debugPrint('Suggestion: start=$currentStart, end=$currentEnd, isDeletion=${suggestion.isDeletion}');
          debugPrint('Text length: ${text.length}');
          continue; // Skip this suggestion if it fails
        }
      }
      
      // Update the controller and state
      _contentController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      
      setState(() {
        _aiSuggestions.clear();
        _showFormattedPreview = true; // Show markdown again after accepting all
        _hasChanges = true;
      });
      
      Get.snackbar('Success', 'All suggestions applied',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green[100], colorText: Colors.green[800]);
    } catch (e) {
      debugPrint('Error in _acceptAllSuggestions: $e');
      Get.snackbar('Error', 'Failed to apply some suggestions',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red[100], colorText: Colors.red[800]);
    }
  }

  void _declineSuggestion(AISuggestion suggestion) {
    setState(() {
      _aiSuggestions.remove(suggestion);
      // Show markdown again if no more suggestions
      if (_aiSuggestions.isEmpty) {
        _showFormattedPreview = true;
      }
    });
  }

  void _declineAllSuggestions() {
    setState(() {
      _aiSuggestions.clear();
      _showFormattedPreview = true; // Show markdown again after declining all
    });
    Get.snackbar('Info', 'All suggestions declined',
      snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.blue[100], colorText: Colors.blue[800]);
  }

  void _adjustSuggestionsAfterEdit(int editStart, int editLength, int newLength) {
    final diff = newLength - editLength;
    for (final suggestion in _aiSuggestions) {
      if (suggestion.start > editStart) {
        // Adjust position
        final newSuggestion = AISuggestion(
          start: suggestion.start + diff,
          end: suggestion.end + diff,
          replacement: suggestion.replacement,
          isDeletion: suggestion.isDeletion,
          originalText: suggestion.originalText,
        );
        final index = _aiSuggestions.indexOf(suggestion);
        _aiSuggestions[index] = newSuggestion;
      }
    }
  }

  Widget _buildAIAssistantPanel(bool isDark) {
    // Animate panel appearance
    if (_showAIAssistant && !_aiPanelAnimationController.isAnimating) {
      _aiPanelAnimationController.forward();
    } else if (!_showAIAssistant && _aiPanelAnimationController.isCompleted) {
      _aiPanelAnimationController.reverse();
    }
    
    return SlideTransition(
      position: _aiPanelSlideAnimation,
      child: FadeTransition(
        opacity: _aiPanelFadeAnimation,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.grey[900]!.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
                border: Border(
                  top: BorderSide(
                    color: isDark 
                      ? Colors.grey[700]!.withValues(alpha: 0.5)
                      : Colors.grey[300]!.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy, size: 20, color: isDark ? Colors.blue[300] : Colors.blue[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Assistant',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _showAIAssistant = false;
                        _aiPromptController.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show thinking indicator or input field
              if (_aiProcessing)
                _buildThinkingIndicator(isDark)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiPromptController,
                        maxLines: null,
                        minLines: 1,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: isDark ? Colors.grey[100] : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask AI to help edit your document...',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          filled: true,
                          fillColor: isDark 
                            ? Colors.grey[800]!.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.blue[400]! : Colors.blue[600]!, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty && !_aiProcessing) {
                            _processAIRequest(value);
                            _aiPromptController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send, color: isDark ? Colors.blue[300] : Colors.blue[600]),
                      onPressed: () {
                        if (_aiPromptController.text.trim().isNotEmpty && !_aiProcessing) {
                          _processAIRequest(_aiPromptController.text);
                          _aiPromptController.clear();
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AI is thinking',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          JumpingDotsIndicator(isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildAISuggestionsDrawer(bool isDark) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Suggestions',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                  ),
                ],
              ),
            ),
            // Accept All / Decline All buttons
            if (_aiSuggestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _acceptAllSuggestions,
                        icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        label: Text(
                          'Accept All (${_aiSuggestions.length})',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _declineAllSuggestions,
                        icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                        label: const Text(
                          'Decline All',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Suggestions list
            Expanded(
              child: _aiSuggestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 64,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No AI suggestions',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildSuggestionsAsParagraphs(isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsAsParagraphs(bool isDark) {
    final List<Widget> paragraphs = [];
    
    // Sort suggestions by position
    final sortedSuggestions = List<AISuggestion>.from(_aiSuggestions)
      ..sort((a, b) => a.start.compareTo(b.start));
    
    for (final suggestion in sortedSuggestions) {
      // Add original text paragraph (if exists)
      if (suggestion.originalText.isNotEmpty) {
        paragraphs.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Texto original:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.originalText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: isDark ? Colors.grey[200] : Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSuggestionButtons(suggestion, true, isDark),
              ],
            ),
          ),
        );
      }
      
      // Add new text paragraph in green
      if (suggestion.replacement != null && suggestion.replacement!.isNotEmpty) {
        paragraphs.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Nuevo texto:',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.replacement!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSuggestionButtons(suggestion, false, isDark),
              ],
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs,
    );
  }

  Widget _buildSuggestionButtons(AISuggestion suggestion, bool isDeletion, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _acceptSuggestion(suggestion),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.green),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _declineSuggestion(suggestion),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.close, size: 14, color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionsDrawer(bool isDark) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Document Versions',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _scaffoldKey.currentState?.closeEndDrawer(),
                  ),
                ],
              ),
            ),
            // Versions list
            Expanded(
              child: _loadingVersions
                  ? const Center(child: CircularProgressIndicator())
                  : _versions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No versions yet',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Save the document to create versions',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _versions.length,
                          itemBuilder: (context, index) {
                            final version = _versions[index];
                            final versionNumber = version['version_number'] as int? ?? 0;
                            final createdAt = version['created_at'] as String?;
                            final content = version['content'] as String? ?? '';
                            final changeSummary = version['change_summary'] as String?;
                            final preview = content.length > 100
                                ? '${content.substring(0, 100)}...'
                                : content;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[900] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.blue[900] : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Version $versionNumber',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.blue[200] : Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatVersionDate(createdAt),
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                    if (changeSummary != null && changeSummary.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark 
                                            ? Colors.blue[900]!.withValues(alpha: 0.3)
                                            : Colors.blue[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark 
                                              ? Colors.blue[700]!.withValues(alpha: 0.5)
                                              : Colors.blue[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.auto_awesome,
                                              size: 16,
                                              color: isDark ? Colors.blue[300] : Colors.blue[700],
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                changeSummary,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: isDark ? Colors.blue[200] : Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      preview,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.restore),
                                  tooltip: 'Restore this version',
                                  onPressed: () => _restoreVersion(version),
                                ),
                                onTap: () => _restoreVersion(version),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom TextField that displays markdown with formatting while editing
class _MarkdownTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool isDark;
  final bool showFormattedPreview;
  final List<AISuggestion> aiSuggestions;
  final Function(AISuggestion) onAcceptSuggestion;
  final Function(AISuggestion) onDeclineSuggestion;
  final VoidCallback onAcceptAll;
  final VoidCallback onDeclineAll;

  const _MarkdownTextField({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.isDark,
    required this.showFormattedPreview,
    required this.aiSuggestions,
    required this.onAcceptSuggestion,
    required this.onDeclineSuggestion,
    required this.onAcceptAll,
    required this.onDeclineAll,
  });

  @override
  State<_MarkdownTextField> createState() => _MarkdownTextFieldState();
}

class _MarkdownTextFieldState extends State<_MarkdownTextField> {
  @override
  void initState() {
    super.initState();
    // Listen to controller changes to rebuild markdown preview
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Rebuild to update markdown preview
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: widget.scrollController,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background: Formatted markdown display (only when no suggestions)
                _buildFormattedBackground(),
                // Foreground: Editable TextField - always shows real text
                _buildTextField(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormattedBackground() {
    // When there are AI suggestions, don't show formatted background
    // The TextField will show the real text and suggestions will be shown separately
    if (!widget.showFormattedPreview || widget.aiSuggestions.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: true, // Ignore pointer events so TextField can receive them
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: MarkdownBody(
              data: widget.controller.text.isEmpty ? '' : widget.controller.text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: widget.isDark ? Colors.grey[100] : Colors.black87,
                  height: 1.6,
                ),
                h1: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                h2: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                h3: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                h4: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                  height: 1.2,
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                  color: widget.isDark ? Colors.green[300] : Colors.green[800],
                ),
                codeblockDecoration: BoxDecoration(
                  color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquote: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  height: 1.6,
                ),
                listBullet: TextStyle(
                  fontFamily: 'Poppins',
                  color: widget.isDark ? Colors.grey[100] : Colors.black87,
                ),
                strong: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                em: TextStyle(
                  fontFamily: 'Poppins',
                  fontStyle: FontStyle.italic,
                  color: widget.isDark ? Colors.grey[100] : Colors.black87,
                ),
                a: TextStyle(
                  fontFamily: 'Poppins',
                  color: widget.isDark ? Colors.blue[300] : Colors.blue[600],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
      ),
    );
  }






  Widget _buildTextField() {
    return IgnorePointer(
      ignoring: false, // Allow pointer events
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: null,
          minLines: null,
          expands: false,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            // Always show text when there are AI suggestions, otherwise follow showFormattedPreview
            color: widget.aiSuggestions.isNotEmpty
                ? (widget.isDark ? Colors.grey[100] : Colors.black87) // Always visible when suggestions exist
                : (widget.showFormattedPreview
                    ? Colors.transparent
                    : (widget.isDark ? Colors.grey[100] : Colors.black87)),
            height: 1.6,
            letterSpacing: 0.0,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          cursorColor: widget.isDark ? Colors.white : Colors.black87,
          cursorWidth: 2.5,
          cursorRadius: const Radius.circular(1),
          showCursor: true,
          enableInteractiveSelection: true,
          enableSuggestions: true,
          autocorrect: true,
          smartDashesType: SmartDashesType.enabled,
          smartQuotesType: SmartQuotesType.enabled,
          decoration: InputDecoration(
            hintText: 'Start writing your document...\n\nUse the toolbar above to format your text with Markdown.\n\nClick the AI icon to get assistance.',
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isDense: false,
          ),
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          buildCounter: null,
        ),
      ),
    );
  }
}

/// Animated jumping dots indicator for AI thinking state
class JumpingDotsIndicator extends StatefulWidget {
  final bool isDark;

  const JumpingDotsIndicator({super.key, required this.isDark});

  @override
  State<JumpingDotsIndicator> createState() => _JumpingDotsIndicatorState();
}

class _JumpingDotsIndicatorState extends State<JumpingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = (_controller.value + delay) % 1.0;
            final offset = (animationValue < 0.5)
                ? animationValue * 2.0
                : 2.0 - (animationValue * 2.0);
            final yOffset = -8.0 * (1 - offset);
            
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Opacity(
                opacity: 0.3 + (offset * 0.7),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
