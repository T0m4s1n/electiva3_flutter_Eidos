import 'package:flutter/material.dart';
import '../widgets/animated_icon_background.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  double _temperature = 0.7;
  double _topP = 1.0;
  int _maxTokens = 1000;
  bool _streamingResponses = true;
  bool _enableSafety = true;
  bool _autoSummarize = false;
  final TextEditingController _systemPromptController = TextEditingController();

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Advanced Settings', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: Theme.of(context).cardTheme.color,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: ChatIconBackground()),
            SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, Icons.tune, 'Generation settings'),
                const SizedBox(height: 12),
                _buildSliderCard(
                  context,
                  title: 'Temperature',
                  subtitle: 'Higher values = more creative (0.0 – 1.5)',
                  value: _temperature,
                  min: 0.0,
                  max: 1.5,
                  divisions: 30,
                  onChanged: (v) => setState(() => _temperature = v),
                ),
                const SizedBox(height: 12),
                _buildSliderCard(
                  context,
                  title: 'Top-p',
                  subtitle: 'Nucleus sampling (0.0 – 1.0)',
                  value: _topP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) => setState(() => _topP = v),
                ),
                const SizedBox(height: 12),
                _buildTokensCard(context),

                const SizedBox(height: 24),
                _buildSectionHeader(context, Icons.shield_outlined, 'Safety & streaming'),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  context,
                  icon: Icons.play_circle_outline,
                  title: 'Stream responses',
                  subtitle: 'Show tokens as they generate',
                  value: _streamingResponses,
                  onChanged: (v) => setState(() => _streamingResponses = v),
                ),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  context,
                  icon: Icons.security_outlined,
                  title: 'Enable safety filters',
                  subtitle: 'Block unsafe content (skeleton only)',
                  value: _enableSafety,
                  onChanged: (v) => setState(() => _enableSafety = v),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader(context, Icons.notes_outlined, 'System prompt'),
                const SizedBox(height: 12),
                _buildSystemPromptCard(context, isDark),

                const SizedBox(height: 24),
                _buildSectionHeader(context, Icons.auto_awesome_outlined, 'Automation'),
                const SizedBox(height: 12),
                _buildSwitchCard(
                  context,
                  icon: Icons.summarize_outlined,
                  title: 'Auto-summarize chats',
                  subtitle: 'Keep brief summaries up to date',
                  value: _autoSummarize,
                  onChanged: (v) => setState(() => _autoSummarize = v),
                ),

                const SizedBox(height: 24),
                _buildSaveBar(context),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
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

  Widget _buildSliderCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text(subtitle, style: _subtitleStyle(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: value.toStringAsFixed(2),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  value.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: _valueStyle(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokensCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Max tokens', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('Limit the maximum tokens in a single response', style: _subtitleStyle(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxTokens.toDouble(),
                  min: 64,
                  max: 4000,
                  divisions: 62,
                  label: _maxTokens.toString(),
                  onChanged: (v) => setState(() => _maxTokens = v.toInt()),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(_maxTokens.toString(), textAlign: TextAlign.end, style: _valueStyle(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.black87),
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle(context)),
                const SizedBox(height: 2),
                Text(subtitle, style: _subtitleStyle(context)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSystemPromptCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Default system prompt', style: _titleStyle(context)),
          const SizedBox(height: 4),
          Text('Applied to new chats unless overridden (skeleton only)', style: _subtitleStyle(context)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _systemPromptController,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'You are a helpful AI assistant... ',
              hintStyle: TextStyle(fontFamily: 'Poppins', color: isDark ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.black87),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.black87),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.black87),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Skeleton: no persistence, just acknowledge
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved (local only)', style: TextStyle(fontFamily: 'Poppins'))),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ),
      ],
    );
  }

  BoxDecoration _surfaceDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.black87, width: 1.5),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    );
  }

  TextStyle _titleStyle(BuildContext context) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  TextStyle _subtitleStyle(BuildContext context) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
      );

  TextStyle _valueStyle(BuildContext context) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      );
}



