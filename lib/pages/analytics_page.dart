import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/chat_database.dart';
import '../widgets/animated_icon_background.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _numConversations = 0;
  int _numMessages = 0;
  int _numDocuments = 0;
  double _avgMessagesPerConv = 0;
  double _avgDocsPerConv = 0;
  List<_DailyPoint> _last7DaysMessages = [];
  List<_DailyPoint> _last7DaysConvs = [];
  List<_DailyPoint> _last7DaysDocs = [];
  List<Map<String, Object?>> _topConversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final Database db = await ChatDatabase.instance;
      final convs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM conversations')) ?? 0;
      final msgs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM messages WHERE is_deleted = 0')) ?? 0;
      final docs = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents')) ?? 0;

      final double avgMsgs = convs == 0 ? 0.0 : msgs.toDouble() / convs.toDouble();
      final double avgDocs = convs == 0 ? 0.0 : docs.toDouble() / convs.toDouble();

      final now = DateTime.now().toUtc();
      final start = now.subtract(const Duration(days: 6));
      List<_DailyPoint> msgs7 = [];
      List<_DailyPoint> convs7 = [];
      List<_DailyPoint> docs7 = [];
      for (int i = 0; i < 7; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        final dayStart = DateTime(day.year, day.month, day.day).toIso8601String();
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
        final m = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM messages WHERE is_deleted = 0 AND created_at BETWEEN ? AND ?', [dayStart, dayEnd])) ?? 0;
        final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM conversations WHERE created_at BETWEEN ? AND ?', [dayStart, dayEnd])) ?? 0;
        final d = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM documents WHERE created_at BETWEEN ? AND ?', [dayStart, dayEnd])) ?? 0;
        msgs7.add(_DailyPoint(label: _fmtDay(day), value: m));
        convs7.add(_DailyPoint(label: _fmtDay(day), value: c));
        docs7.add(_DailyPoint(label: _fmtDay(day), value: d));
      }

      final top = await db.rawQuery(
        'SELECT conversations.id, conversations.title, COUNT(messages.id) as msgCount '
        'FROM conversations '
        'LEFT JOIN messages ON messages.conversation_id = conversations.id AND messages.is_deleted = 0 '
        'GROUP BY conversations.id '
        'ORDER BY msgCount DESC, conversations.updated_at DESC '
        'LIMIT 5',
      );
      setState(() {
        _numConversations = convs;
        _numMessages = msgs;
        _numDocuments = docs;
        _avgMessagesPerConv = avgMsgs;
        _avgDocsPerConv = avgDocs;
        _last7DaysMessages = msgs7;
        _last7DaysConvs = convs7;
        _last7DaysDocs = docs7;
        _topConversations = top;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Theme.of(context).cardTheme.color,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatPyramidBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview cards grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 640;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                              child: _buildStatCard(context, 'Total conversations', _numConversations.toString(), Icons.forum_outlined),
                            ),
                            SizedBox(
                              width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                              child: _buildStatCard(context, 'Total messages', _numMessages.toString(), Icons.chat_bubble_outline),
                            ),
                            SizedBox(
                              width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                              child: _buildStatCard(context, 'Total documents', _numDocuments.toString(), Icons.description_outlined),
                            ),
                            SizedBox(
                              width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                              child: _buildStatCard(context, 'Avg messages per chat', _avgMessagesPerConv.toStringAsFixed(2), Icons.trending_up),
                            ),
                            if (isWide)
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: _buildStatCard(context, 'Avg docs per chat', _avgDocsPerConv.toStringAsFixed(2), Icons.sticky_note_2_outlined),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'Last 7 days'),
                    const SizedBox(height: 12),
                    _buildBarChart(context, 'Messages', _last7DaysMessages, Colors.blue),
                    const SizedBox(height: 12),
                    _buildBarChart(context, 'Conversations', _last7DaysConvs, Colors.purple),
                    const SizedBox(height: 12),
                    _buildBarChart(context, 'Documents', _last7DaysDocs, Colors.teal),

                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'Top conversations'),
                    const SizedBox(height: 12),
                    _buildTopConversations(context),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87),
            ),
            child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontFamily: 'Poppins', fontSize: 20, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Icon(Icons.insights_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, String title, List<_DailyPoint> points, Color color) {
    final int maxVal = points.isEmpty ? 0 : points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final double h = maxVal == 0 ? 0 : (p.value / maxVal) * 120;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(p.label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopConversations(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_topConversations.isEmpty) {
      return Text('No conversations yet', style: TextStyle(fontFamily: 'Poppins', color: isDark ? Colors.grey[400] : Colors.grey[600]));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87, width: 1.5),
      ),
      child: Column(
        children: _topConversations.map((row) {
          final title = (row['title'] as String?)?.trim();
          final display = (title == null || title.isEmpty) ? 'Untitled Chat' : title;
          final count = (row['msgCount'] as int?) ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(display, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87),
                  ),
                  child: Text('$count msgs', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmtDay(DateTime d) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[d.weekday % 7];
  }
}

class _DailyPoint {
  final String label;
  final int value;
  _DailyPoint({required this.label, required this.value});
}



