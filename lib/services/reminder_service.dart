import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:uuid/uuid.dart';
import 'chat_database.dart';
import 'auth_service.dart';

class ReminderService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize the reminder service and local notifications
  static Future<void> init() async {
    if (_initialized) {
      debugPrint('ReminderService: Already initialized');
      return;
    }

    try {
      debugPrint('ReminderService: Starting initialization...');
      
      // Initialize timezone
      tz.initializeTimeZones();
      final location = tz.getLocation('America/New_York'); // Default timezone, can be made configurable
      tz.setLocalLocation(location);
      debugPrint('ReminderService: Timezone initialized to ${location.name}');

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      debugPrint('ReminderService: Initializing notifications plugin...');
      final bool? initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      if (initialized != true) {
        throw Exception('Failed to initialize notifications plugin');
      }
      debugPrint('ReminderService: Notifications plugin initialized successfully');

      // Request permissions
      debugPrint('ReminderService: Requesting permissions...');
      await _requestPermissions();

      // Create local database table for reminders
      debugPrint('ReminderService: Creating local table...');
      await _createLocalTable();

      _initialized = true;
      debugPrint('ReminderService: Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('ReminderService: Error initializing - $e');
      debugPrint('ReminderService: Stack trace - $stackTrace');
      // Don't set _initialized to true if initialization failed
      rethrow;
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  /// Create local reminders table
  /// Note: The reminders table is now created in ChatDatabase schema (v5)
  /// This method ensures the table exists as a fallback
  static Future<void> _createLocalTable() async {
    try {
      final Database db = await ChatDatabase.instance;
      // The table should already exist from ChatDatabase schema
      // But we'll ensure it exists as a fallback
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reminders (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT NOT NULL,
          description TEXT,
          reminder_date TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          created_from_chat INTEGER NOT NULL DEFAULT 0,
          conversation_id TEXT,
          message_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_date ON reminders(reminder_date)');
      debugPrint('ReminderService: Local table verified/created');
    } catch (e) {
      debugPrint('ReminderService: Error creating local table - $e');
      // Re-throw to ensure the error is visible
      rethrow;
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('ReminderService: Notification tapped: ${response.payload}');
    // Handle navigation to reminder or conversation
  }

  /// Create a reminder from chat message
  static Future<String> createReminderFromChat({
    required String title,
    String? description,
    required DateTime reminderDate,
    String? conversationId,
    String? messageId,
  }) async {
    try {
      final String reminderId = const Uuid().v4();
      final String? userId = AuthService.currentUser?.id;
      final String now = DateTime.now().toUtc().toIso8601String();

      // Save locally first
      final Database db = await ChatDatabase.instance;
      await db.insert('reminders', {
        'id': reminderId,
        'user_id': userId,
        'title': title,
        'description': description,
        'reminder_date': reminderDate.toUtc().toIso8601String(),
        'is_completed': 0,
        'created_from_chat': 1,
        'conversation_id': conversationId,
        'message_id': messageId,
        'created_at': now,
        'updated_at': now,
      });

      debugPrint('ReminderService: Reminder saved locally: $reminderId');

      // Schedule local notification for the reminder
      await _scheduleNotification(
        id: reminderId.hashCode,
        title: title,
        body: description ?? title,
        scheduledDate: reminderDate,
      );

      // Save to Supabase if logged in
      if (userId != null) {
        try {
          await _supabase.from('reminders').insert({
            'id': reminderId,
            'user_id': userId,
            'title': title,
            'description': description,
            'reminder_date': reminderDate.toUtc().toIso8601String(),
            'is_completed': false,
            'created_from_chat': true,
            'conversation_id': conversationId,
            'message_id': messageId,
          });
          debugPrint('ReminderService: Reminder saved to Supabase: $reminderId');
        } catch (e) {
          debugPrint('ReminderService: Error saving to Supabase - $e');
          // Continue with local storage
        }
      }

      // Send immediate notification confirming reminder creation
      await _showReminderCreatedNotification(
        title: title,
        reminderDate: reminderDate,
      );

      return reminderId;
    } catch (e) {
      debugPrint('ReminderService: Error creating reminder - $e');
      rethrow;
    }
  }

  /// Show immediate notification when reminder is created
  static Future<void> _showReminderCreatedNotification({
    required String title,
    required DateTime reminderDate,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final String formattedDate = _formatReminderDate(reminderDate);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminders',
        'Reminders',
        channelDescription: 'Notifications for reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        now.millisecondsSinceEpoch % 100000, // Use a unique ID based on timestamp
        'Reminder Created',
        'Reminder "$title" scheduled for $formattedDate',
        details,
      );

      debugPrint('ReminderService: Reminder created notification sent');
    } catch (e) {
      debugPrint('ReminderService: Error showing reminder created notification - $e');
    }
  }

  /// Format reminder date for notification
  static String _formatReminderDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime reminderDay = DateTime(date.year, date.month, date.day);
    final int difference = reminderDay.difference(today).inDays;

    if (difference == 0) {
      // Today
      return 'today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      // Tomorrow
      return 'tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference < 7) {
      // This week
      final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return '${weekdays[date.weekday - 1]} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // Future date
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Schedule a local notification
  /// This notification will appear even when the app is in the background or closed
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

      // Android notification configuration for background notifications
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminders', // Channel ID
        'Reminders', // Channel name
        channelDescription: 'Notifications for reminders and scheduled tasks',
        importance: Importance.high, // High importance shows on screen even when locked
        priority: Priority.high, // High priority for immediate delivery
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: true,
        ongoing: false, // Not ongoing, so it can be dismissed
      );

      // iOS notification configuration
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true, // Show alert
        presentBadge: true, // Update app badge
        presentSound: true, // Play sound
        sound: 'default', // Use default notification sound
        interruptionLevel: InterruptionLevel.active, // Show even in Do Not Disturb
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule notification - works even when app is closed
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Works in doze mode
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Match by time
      );

      debugPrint('ReminderService: Notification scheduled for $scheduledDate (will appear even when app is closed)');
    } catch (e) {
      debugPrint('ReminderService: Error scheduling notification - $e');
      rethrow;
    }
  }

  /// Get all active reminders for the current user
  static Future<List<Map<String, dynamic>>> getActiveReminders() async {
    try {
      final Database db = await ChatDatabase.instance;
      final String? userId = AuthService.currentUser?.id;

      final List<Map<String, Object?>> reminders = await db.query(
        'reminders',
        where: userId != null ? 'user_id = ? AND is_completed = 0' : 'is_completed = 0',
        whereArgs: userId != null ? [userId] : null,
        orderBy: 'reminder_date ASC',
      );

      return reminders.map((r) => {
        'id': r['id'],
        'title': r['title'],
        'description': r['description'],
        'reminder_date': r['reminder_date'],
        'is_completed': (r['is_completed'] as int?) == 1,
        'created_from_chat': (r['created_from_chat'] as int?) == 1,
        'conversation_id': r['conversation_id'],
        'message_id': r['message_id'],
      }).toList();
    } catch (e) {
      debugPrint('ReminderService: Error getting reminders - $e');
      return [];
    }
  }

  /// Mark reminder as completed
  static Future<void> completeReminder(String reminderId) async {
    try {
      final Database db = await ChatDatabase.instance;
      await db.update(
        'reminders',
        {'is_completed': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [reminderId],
      );

      // Cancel notification
      await _notifications.cancel(reminderId.hashCode);

      // Update in Supabase if logged in
      final String? userId = AuthService.currentUser?.id;
      if (userId != null) {
        try {
          await _supabase.from('reminders').update({
            'is_completed': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', reminderId);
        } catch (e) {
          debugPrint('ReminderService: Error updating in Supabase - $e');
        }
      }

      debugPrint('ReminderService: Reminder completed: $reminderId');
    } catch (e) {
      debugPrint('ReminderService: Error completing reminder - $e');
      rethrow;
    }
  }

  /// Delete a reminder
  static Future<void> deleteReminder(String reminderId) async {
    try {
      final Database db = await ChatDatabase.instance;
      await db.delete('reminders', where: 'id = ?', whereArgs: [reminderId]);

      // Cancel notification
      await _notifications.cancel(reminderId.hashCode);

      // Delete from Supabase if logged in
      final String? userId = AuthService.currentUser?.id;
      if (userId != null) {
        try {
          await _supabase.from('reminders').delete().eq('id', reminderId);
        } catch (e) {
          debugPrint('ReminderService: Error deleting from Supabase - $e');
        }
      }

      debugPrint('ReminderService: Reminder deleted: $reminderId');
    } catch (e) {
      debugPrint('ReminderService: Error deleting reminder - $e');
      rethrow;
    }
  }

  /// Parse reminder from chat message
  /// Returns a map with 'title', 'description', and 'reminder_date' if a reminder is detected
  /// [isDocumentMode] - Whether the user is in document editing mode
  static Map<String, dynamic>? parseReminderFromMessage(String message, {bool isDocumentMode = false}) {
    final String lowerMessage = message.toLowerCase();

    // Keywords for reminder detection
    final List<String> reminderKeywords = [
      'reminder',
      'remind me',
      'set a reminder',
      'create a reminder',
      'add a reminder',
      'schedule a reminder',
      'recordatorio',
      'recordar',
      'agregar recordatorio',
      'crear recordatorio',
    ];

    final bool hasReminderKeyword = reminderKeywords.any((keyword) => lowerMessage.contains(keyword));

    if (!hasReminderKeyword) {
      return null;
    }

    // Document-related keywords that indicate the user is talking about editing
    final List<String> documentKeywords = [
      'edit',
      'edit this',
      'modify',
      'change',
      'update',
      'revise',
      'adjust',
      'document',
      'text',
      'content',
      'paragraph',
      'section',
      'add to',
      'remove from',
      'delete',
      'rewrite',
      'rephrase',
      'improve',
      'enhance',
    ];

    // Check if the message is about editing a document
    final bool isAboutEditing = documentKeywords.any((keyword) => lowerMessage.contains(keyword));
    
    // Check if there's a clear time reference first
    final bool hasTimeReference = _hasClearTimeReference(message);
    
    // If the message explicitly says "create a reminder" or "set a reminder" with a time reference,
    // prioritize that over document editing context
    final bool isExplicitReminderRequest = lowerMessage.contains('create a reminder') ||
        lowerMessage.contains('set a reminder') ||
        lowerMessage.contains('add a reminder') ||
        lowerMessage.contains('schedule a reminder');
    
    // If in document mode or message is about editing, be more careful
    if (isDocumentMode || isAboutEditing) {
      // If there's an explicit reminder request with time reference, create the reminder
      if (isExplicitReminderRequest && hasTimeReference) {
        debugPrint('ReminderService: Explicit reminder request with time reference, creating reminder');
        // Continue to create reminder
      } else if (!hasTimeReference) {
        // No clear time reference - likely talking about editing, not creating a reminder
        debugPrint('ReminderService: Message about editing without time reference, skipping reminder creation');
        return null;
      }
    }

    // Try to extract date/time from message
    DateTime? reminderDate = _extractDateTimeFromMessage(message);

    // Default to 1 hour from now if no date found
    if (reminderDate == null) {
      reminderDate = DateTime.now().add(const Duration(hours: 1));
    }

    // Extract title (everything after "reminder" or similar keywords)
    String title = message;
    for (final keyword in reminderKeywords) {
      final index = lowerMessage.indexOf(keyword);
      if (index != -1) {
        title = message.substring(index + keyword.length).trim();
        break;
      }
    }

    // Clean up title
    if (title.isEmpty) {
      title = 'Reminder';
    }

    // Remove time/date words from title if present
    title = title.replaceAll(RegExp(r'\b(tomorrow|today|now|in|at|on)\b', caseSensitive: false), '').trim();
    title = title.replaceAll(RegExp(r'\d{1,2}:\d{2}'), '').trim();
    title = title.replaceAll(RegExp(r'\d{1,2}/\d{1,2}/\d{4}'), '').trim();

    if (title.isEmpty) {
      title = 'Reminder';
    }

    // Ensure reminder date is not in the past
    if (reminderDate.isBefore(DateTime.now())) {
      reminderDate = DateTime.now().add(const Duration(hours: 1));
    }

    return {
      'title': title,
      'description': message,
      'reminder_date': reminderDate,
    };
  }

  /// Check if message has a clear time reference for reminder
  static bool _hasClearTimeReference(String message) {
    final String lowerMessage = message.toLowerCase();
    
    // Patterns that indicate a clear time reference
    final List<RegExp> timePatterns = [
      // "in X minutes/hours/days/weeks"
      RegExp(r'\bin\s+\d+\s+(minute|hour|day|week)s?\b', caseSensitive: false),
      // "tomorrow"
      RegExp(r'\btomorrow\b', caseSensitive: false),
      // "today at X:XX" or "at X:XX"
      RegExp(r'\b(today\s+)?at\s+\d{1,2}:\d{2}\b', caseSensitive: false),
      // "in X hours/days"
      RegExp(r'\bin\s+\d+\s+(hour|day)s?\b', caseSensitive: false),
      // "on [day]" like "on Monday", "on Friday"
      RegExp(r'\bon\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      // "next [day]" like "next week", "next Monday"
      RegExp(r'\bnext\s+(week|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
      // "at X o'clock" or "at X pm/am"
      RegExp(r"\bat\s+\d{1,2}\s*(o'clock|pm|am)\b", caseSensitive: false),
    ];

    // Check if any time pattern matches
    return timePatterns.any((pattern) => pattern.hasMatch(lowerMessage));
  }

  /// Extract date/time from message
  static DateTime? _extractDateTimeFromMessage(String message) {
    final String lowerMessage = message.toLowerCase();
    final DateTime now = DateTime.now();

    // Check for "in X minutes/hours/days"
    final RegExp inTimeRegex = RegExp(r'in (\d+) (minute|hour|day|week)s?', caseSensitive: false);
    final match = inTimeRegex.firstMatch(lowerMessage);
    if (match != null) {
      final int amount = int.tryParse(match.group(1) ?? '') ?? 0;
      final String unit = match.group(2)?.toLowerCase() ?? '';
      
      if (unit.startsWith('minute')) {
        return now.add(Duration(minutes: amount));
      } else if (unit.startsWith('hour')) {
        return now.add(Duration(hours: amount));
      } else if (unit.startsWith('day')) {
        return now.add(Duration(days: amount));
      } else if (unit.startsWith('week')) {
        return now.add(Duration(days: amount * 7));
      }
    }

    // Check for "tomorrow"
    if (lowerMessage.contains('tomorrow')) {
      return DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    // Check for "today at X:XX"
    final RegExp timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final timeMatch = timeRegex.firstMatch(message);
    if (timeMatch != null && lowerMessage.contains('today')) {
      final int hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
      final int minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      final DateTime todayTime = DateTime(now.year, now.month, now.day, hour, minute);
      return todayTime.isBefore(now) ? todayTime.add(const Duration(days: 1)) : todayTime;
    }

    // Default: 1 hour from now
    return now.add(const Duration(hours: 1));
  }
}

