import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/animated_icon_background.dart';
import '../services/hive_storage_service.dart';
import '../services/advanced_settings_service.dart';
import '../services/chat_database.dart';
import '../services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  int _maxTokens = 1000;
  bool _applyToAllChats = true; // true = all chats, false = current chat only
  bool _autoClearCache = false;
  bool _enableAnalytics = true;
  bool _enableCrashReports = true;
  bool _autoSync = true;
  
  String _storageSize = 'Calculating...';
  String _cacheSize = 'Calculating...';
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateStorageStats();
  }

  Future<void> _loadSettings() async {
    try {
      // Try to load from Supabase first
      final settings = await AdvancedSettingsService.getAdvancedSettings();
      
      if (settings != null) {
        setState(() {
          _maxTokens = settings['max_tokens'] as int? ?? 1000;
          _applyToAllChats = settings['apply_to_all_chats'] as bool? ?? true;
          _autoClearCache = settings['auto_clear_cache'] as bool? ?? false;
          _enableAnalytics = settings['enable_analytics'] as bool? ?? true;
          _enableCrashReports = settings['enable_crash_reports'] as bool? ?? true;
          _autoSync = settings['auto_sync'] as bool? ?? true;
        });
      } else {
        // Fallback to local storage if not logged in
        setState(() {
          _maxTokens = HiveStorageService.loadMaxTokens();
          _applyToAllChats = HiveStorageService.loadMaxTokensScope() ?? true;
        });
      }
    } catch (e) {
      // Fallback to local storage on error
      setState(() {
        _maxTokens = HiveStorageService.loadMaxTokens();
        _applyToAllChats = HiveStorageService.loadMaxTokensScope() ?? true;
      });
    }
  }

  Future<void> _calculateStorageStats() async {
    try {
      setState(() => _isLoadingStats = true);
      
      // Calculate database size
      final db = await ChatDatabase.instance;
      final dbPath = db.path;
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final dbSize = await dbFile.length();
        _storageSize = _formatBytes(dbSize);
      } else {
        _storageSize = '0 B';
      }

      // Calculate cache size (app directory)
      final appDir = await getApplicationDocumentsDirectory();
      int cacheSize = await _calculateDirectorySize(appDir);
      _cacheSize = _formatBytes(cacheSize);
    } catch (e) {
      _storageSize = 'Error';
      _cacheSize = 'Error';
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<int> _calculateDirectorySize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Clear Cache',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will clear all cached data. This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear cache logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared', style: TextStyle(fontFamily: 'Poppins')),
        ),
      );
      _calculateStorageStats();
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Save to Supabase if logged in
      if (AuthService.isLoggedIn) {
        await AdvancedSettingsService.saveAdvancedSettings(
          maxTokens: _maxTokens,
          applyToAllChats: _applyToAllChats,
          autoClearCache: _autoClearCache,
          enableAnalytics: _enableAnalytics,
          enableCrashReports: _enableCrashReports,
          autoSync: _autoSync,
        );
        
        // Also save to local storage as backup
        await HiveStorageService.saveMaxTokens(_maxTokens);
        await HiveStorageService.saveMaxTokensScope(_applyToAllChats);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Settings saved successfully',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              duration: Duration(seconds: 1),
            ),
          );
        }
        
        // Navigate back to preferences after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Get.back();
        }
      } else {
        // Save to local storage only if not logged in
        await HiveStorageService.saveMaxTokens(_maxTokens);
        await HiveStorageService.saveMaxTokensScope(_applyToAllChats);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Settings saved locally (login to sync)',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              duration: Duration(seconds: 1),
            ),
          );
        }
        
        // Navigate back to preferences after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Get.back();
        }
      }
    } catch (e) {
      // Fallback to local storage on error
      await HiveStorageService.saveMaxTokens(_maxTokens);
      await HiveStorageService.saveMaxTokensScope(_applyToAllChats);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving to cloud: $e. Saved locally.',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
      // Navigate back to preferences even on error
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    // Response Limits Section
                    _buildSectionHeader(
                      context,
                      Icons.speed_outlined,
                      'Response Limits',
                      'Control the maximum length of AI responses',
                    ),
                    const SizedBox(height: 12),
                    _buildTokensCard(context),

                    const SizedBox(height: 24),

                    // App Settings Section
                    _buildSectionHeader(
                      context,
                      Icons.settings_outlined,
                      'App Settings',
                      'Manage app behavior and data',
                    ),
                    const SizedBox(height: 12),
                    _buildStorageCard(context),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      context,
                      icon: Icons.auto_delete_outlined,
                      title: 'Auto-clear cache',
                      subtitle: 'Automatically clear cache on app close',
                      value: _autoClearCache,
                      onChanged: (v) => setState(() => _autoClearCache = v),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      context,
                      icon: Icons.analytics_outlined,
                      title: 'Analytics',
                      subtitle: 'Help improve the app by sharing usage data',
                      value: _enableAnalytics,
                      onChanged: (v) => setState(() => _enableAnalytics = v),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      context,
                      icon: Icons.bug_report_outlined,
                      title: 'Crash reports',
                      subtitle: 'Automatically send crash reports',
                      value: _enableCrashReports,
                      onChanged: (v) => setState(() => _enableCrashReports = v),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      context,
                      icon: Icons.cloud_sync_outlined,
                      title: 'Auto-sync',
                      subtitle: 'Automatically sync chats and data to cloud',
                      value: _autoSync,
                      onChanged: (v) => setState(() => _autoSync = v),
                    ),

                    const SizedBox(height: 24),

                    // Data Management Section
                    _buildSectionHeader(
                      context,
                      Icons.storage_outlined,
                      'Data Management',
                      'Manage your stored data',
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      context,
                      icon: Icons.delete_sweep_outlined,
                      title: 'Clear Cache',
                      subtitle: 'Remove temporary files and cache',
                      onTap: _clearCache,
                      color: Colors.orange,
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

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTokensCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.numbers_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Max Tokens', style: _titleStyle(context)),
                    const SizedBox(height: 2),
                    Text('Maximum response length', style: _subtitleStyle(context)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _maxTokens.toString(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_maxTokens / 1000).toStringAsFixed(1)}k',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _applyToAllChats ? Icons.chat_bubble_outline : Icons.chat_bubble,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _applyToAllChats ? 'Apply to all chats' : 'Apply to current chat',
                        style: _titleStyle(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _applyToAllChats 
                          ? 'This limit will be used for all conversations'
                          : 'This limit will only apply to the current chat',
                        style: _subtitleStyle(context),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _applyToAllChats,
                  onChanged: (v) => setState(() => _applyToAllChats = v),
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storage_outlined,
                  size: 18,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Usage', style: _titleStyle(context)),
                    const SizedBox(height: 2),
                    Text('Database and cache size', style: _subtitleStyle(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildStorageInfo(
                  context,
                  'Database',
                  _storageSize,
                  Icons.storage_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStorageInfo(
                  context,
                  'Cache',
                  _cacheSize,
                  Icons.cached_outlined,
                ),
              ),
            ],
          ),
          if (_isLoadingStats)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.black87,
              ),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
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
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
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
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.black87,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _surfaceDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600]!
            : Colors.black87,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[600],
      );
}


