import 'package:flutter/material.dart';
import '../widgets/animated_icon_background.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _enablePush = true;
  bool _enableEmail = false;
  bool _enableInApp = true;
  bool _sound = true;
  bool _vibration = true;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontFamily: 'Poppins')),
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
                _buildSectionHeader(context, Icons.notifications_active_outlined, 'Channels'),
                const SizedBox(height: 12),
                _buildSwitch(context, 'Push notifications', 'Receive push alerts on your device', _enablePush, (v) => setState(() => _enablePush = v)),
                const SizedBox(height: 8),
                _buildSwitch(context, 'Email', 'Get updates via email', _enableEmail, (v) => setState(() => _enableEmail = v)),
                const SizedBox(height: 8),
                _buildSwitch(context, 'In-app banners', 'Show banners inside the app', _enableInApp, (v) => setState(() => _enableInApp = v)),

                const SizedBox(height: 24),
                _buildSectionHeader(context, Icons.volume_up_outlined, 'Preferences'),
                const SizedBox(height: 12),
                _buildSwitch(context, 'Sound', 'Play a sound for notifications', _sound, (v) => setState(() => _sound = v)),
                const SizedBox(height: 8),
                _buildSwitch(context, 'Vibration', 'Vibrate on notification', _vibration, (v) => setState(() => _vibration = v)),

                const SizedBox(height: 24),
                _buildSectionHeader(context, Icons.nights_stay_outlined, 'Quiet hours'),
                const SizedBox(height: 12),
                _buildQuietHours(context),

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

  Widget _buildSwitch(BuildContext context, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.black87, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildQuietHours(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.black87, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do not disturb', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text('Silence notifications during these hours', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          _buildTimeChip(context, _quietStart, () async {
            final picked = await showTimePicker(context: context, initialTime: _quietStart);
            if (picked != null) setState(() => _quietStart = picked);
          }),
          const SizedBox(width: 8),
          const Text('–', style: TextStyle(fontFamily: 'Poppins')),
          const SizedBox(width: 8),
          _buildTimeChip(context, _quietEnd, () async {
            final picked = await showTimePicker(context: context, initialTime: _quietEnd);
            if (picked != null) setState(() => _quietEnd = picked);
          }),
        ],
      ),
    );
  }

  Widget _buildTimeChip(BuildContext context, TimeOfDay time, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.grey[600]! : Colors.black87),
        ),
        child: Text(
          _formatTime(time),
          style: TextStyle(fontFamily: 'Poppins', color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification settings saved (local only)', style: TextStyle(fontFamily: 'Poppins'))),
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
}



