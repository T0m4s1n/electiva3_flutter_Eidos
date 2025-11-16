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
      // Use the device's local timezone instead of hardcoding
      try {
        // Try to get the device's actual timezone
        final location = tz.local;
        debugPrint('ReminderService: Timezone initialized to ${location.name}');
      } catch (e) {
        // Fallback to a default timezone if we can't detect it
        final location = tz.getLocation('America/New_York');
        tz.setLocalLocation(location);
        debugPrint('ReminderService: Timezone initialized to ${location.name} (fallback)');
      }

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

      // Create notification channel for Android (required for scheduled notifications)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'reminders',
              'Reminders',
              description: 'Notifications for reminders and scheduled tasks',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
          debugPrint('ReminderService: Android notification channel created');
        }
      }

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
      debugPrint('ReminderService: Scheduling notification for reminder: $reminderId');
      debugPrint('ReminderService: Reminder date: $reminderDate');
      debugPrint('ReminderService: Current time: ${DateTime.now()}');
      debugPrint('ReminderService: Time until reminder: ${reminderDate.difference(DateTime.now()).inMinutes} minutes');
      
      await _scheduleNotification(
        id: reminderId.hashCode,
        title: title,
        body: description ?? title,
        scheduledDate: reminderDate,
      );
      
      debugPrint('ReminderService: Notification scheduled successfully');

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
      // Ensure the scheduled date is in the future
      final DateTime now = DateTime.now();
      if (scheduledDate.isBefore(now)) {
        debugPrint('ReminderService: Warning - scheduled date is in the past: $scheduledDate, current time: $now');
        throw Exception('Scheduled date cannot be in the past');
      }

      // Convert to timezone-aware datetime
      // Ensure we're using the device's local timezone
      final tz.Location location = tz.local;
      final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(scheduledDate, location);
      final tz.TZDateTime nowTZ = tz.TZDateTime.from(now, location);
      
      // Verify the timezone conversion
      debugPrint('ReminderService: Scheduling notification for $scheduledDate (local time: $scheduledTZ)');
      debugPrint('ReminderService: Current time: $now (local timezone: ${location.name})');
      debugPrint('ReminderService: Current TZ time: $nowTZ');
      debugPrint('ReminderService: Scheduled TZ time: $scheduledTZ');
      debugPrint('ReminderService: Time difference: ${scheduledTZ.difference(nowTZ).inMinutes} minutes');
      
      // Double-check the scheduled time is in the future
      if (scheduledTZ.isBefore(nowTZ)) {
        debugPrint('ReminderService: ERROR - Scheduled TZ time is in the past!');
        debugPrint('ReminderService: Scheduled: $scheduledTZ, Now: $nowTZ');
        throw Exception('Scheduled timezone-aware date is in the past');
      }

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
      // For very short-term notifications (less than 15 minutes), use exact mode
      // For longer notifications, use exactAllowWhileIdle for better battery optimization
      final int minutesUntilNotification = scheduledTZ.difference(nowTZ).inMinutes;
      final AndroidScheduleMode scheduleMode = minutesUntilNotification < 15
          ? AndroidScheduleMode.exact
          : AndroidScheduleMode.exactAllowWhileIdle;
      
      debugPrint('ReminderService: Using schedule mode: $scheduleMode ($minutesUntilNotification minutes until notification)');
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('ReminderService: Notification scheduled successfully for $scheduledTZ (will appear even when app is closed)');
      
      // Verify the notification was scheduled
      final List<PendingNotificationRequest> pendingNotifications = await _notifications.pendingNotificationRequests();
      final bool isScheduled = pendingNotifications.any((n) => n.id == id);
      if (isScheduled) {
        debugPrint('ReminderService: Notification verified in pending list (ID: $id)');
      } else {
        debugPrint('ReminderService: WARNING - Notification not found in pending list (ID: $id)');
      }
    } catch (e, stackTrace) {
      debugPrint('ReminderService: Error scheduling notification - $e');
      debugPrint('ReminderService: Stack trace - $stackTrace');
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
    reminderDate ??= DateTime.now().add(const Duration(hours: 1));

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
      // "in X minutes/hours/days/weeks" (English)
      RegExp(r'\bin\s+\d+\s+(minute|minutes|hour|hours|day|days|week|weeks)?\b', caseSensitive: false),
      // "en X minutos/horas/días" (Spanish)
      RegExp(r'\ben\s+\d+\s+(minuto|minutos|hora|horas|día|días|semana|semanas)?\b', caseSensitive: false),
      // "X minutos/minutes/horas/hours" (direct, without "en/in")
      RegExp(r'\b\d+\s+(minuto|minutos|minutes?|hora|horas|hours?|día|días|days?|semana|semanas|weeks?)\b', caseSensitive: false),
      // "tomorrow" or "mañana"
      RegExp(r'\b(tomorrow|mañana)\b', caseSensitive: false),
      // "today at X:XX" or "hoy a las X:XX" or "at X:XX"
      RegExp(r'\b(today|hoy\s+)?(at|a las)\s+\d{1,2}:\d{2}\b', caseSensitive: false),
      // "on [day]" like "on Monday", "on Friday", "el lunes", etc.
      RegExp(r'\b(on|el)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miércoles|jueves|viernes|sábado|domingo)\b', caseSensitive: false),
      // "next [day]" like "next week", "next Monday", "próxima semana"
      RegExp(r'\b(next|próxima|próximo)\s+(week|monday|tuesday|wednesday|thursday|friday|saturday|sunday|semana|lunes|martes|miércoles|jueves|viernes|sábado|domingo)\b', caseSensitive: false),
      // "at X o'clock" or "at X pm/am" or "a las X"
      RegExp(r"\b(at|a las)\s+\d{1,2}\s*(o'?clock|pm|am|de la (mañana|tarde|noche))?\b", caseSensitive: false),
    ];

    // Check if any time pattern matches
    return timePatterns.any((pattern) => pattern.hasMatch(lowerMessage));
  }

  /// Extract date/time from message
  static DateTime? _extractDateTimeFromMessage(String message) {
    final String lowerMessage = message.toLowerCase();
    final DateTime now = DateTime.now();

    // Check for "en X minutos/horas/días" (Spanish)
    final RegExp inTimeRegexSpanish = RegExp(r'en\s+(\d+)\s+(minuto|minutos|hora|horas|día|días|semana|semanas)?', caseSensitive: false);
    final matchSpanish = inTimeRegexSpanish.firstMatch(lowerMessage);
    if (matchSpanish != null) {
      final int amount = int.tryParse(matchSpanish.group(1) ?? '') ?? 0;
      final String unit = (matchSpanish.group(2) ?? '').toLowerCase();
      
      if (unit.contains('minuto')) {
        return now.add(Duration(minutes: amount));
      } else if (unit.contains('hora')) {
        return now.add(Duration(hours: amount));
      } else if (unit.contains('día')) {
        return now.add(Duration(days: amount));
      } else if (unit.contains('semana')) {
        return now.add(Duration(days: amount * 7));
      } else if (amount > 0) {
        // If number is found but no unit, default to minutes for small numbers, hours for large
        if (amount <= 60) {
          return now.add(Duration(minutes: amount));
        } else {
          return now.add(Duration(hours: amount));
        }
      }
    }

    // Check for "in X minutes/hours/days" (English)
    final RegExp inTimeRegex = RegExp(r'\bin\s+(\d+)\s+(minute|minutes|hour|hours|day|days|week|weeks)?', caseSensitive: false);
    final match = inTimeRegex.firstMatch(lowerMessage);
    if (match != null) {
      final int amount = int.tryParse(match.group(1) ?? '') ?? 0;
      final String unit = (match.group(2) ?? '').toLowerCase();
      
      if (unit.startsWith('minute')) {
        return now.add(Duration(minutes: amount));
      } else if (unit.startsWith('hour')) {
        return now.add(Duration(hours: amount));
      } else if (unit.startsWith('day')) {
        return now.add(Duration(days: amount));
      } else if (unit.startsWith('week')) {
        return now.add(Duration(days: amount * 7));
      } else if (amount > 0) {
        // If number is found but no unit, default to minutes for small numbers, hours for large
        if (amount <= 60) {
          return now.add(Duration(minutes: amount));
        } else {
          return now.add(Duration(hours: amount));
        }
      }
    }

    // Check for "X minutos/minutes/horas/hours" without "en/in"
    final RegExp directTimeRegex = RegExp(r'(\d+)\s+(minuto|minutos|minutes?|hora|horas|hours?|día|días|days?|semana|semanas|weeks?)\b', caseSensitive: false);
    final directMatch = directTimeRegex.firstMatch(lowerMessage);
    if (directMatch != null) {
      final int amount = int.tryParse(directMatch.group(1) ?? '') ?? 0;
      final String unit = (directMatch.group(2) ?? '').toLowerCase();
      
      if (unit.contains('minuto') || unit.contains('minute')) {
        return now.add(Duration(minutes: amount));
      } else if (unit.contains('hora') || unit.contains('hour')) {
        return now.add(Duration(hours: amount));
      } else if (unit.contains('día') || unit.contains('day')) {
        return now.add(Duration(days: amount));
      } else if (unit.contains('semana') || unit.contains('week')) {
        return now.add(Duration(days: amount * 7));
      }
    }

    // Check for "tomorrow" or "mañana"
    if (lowerMessage.contains('tomorrow') || lowerMessage.contains('mañana')) {
      return DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    // Check for "today at X:XX" or "hoy a las X:XX"
    final RegExp timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final timeMatch = timeRegex.firstMatch(message);
    if (timeMatch != null && (lowerMessage.contains('today') || lowerMessage.contains('hoy'))) {
      final int hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
      final int minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      final DateTime todayTime = DateTime(now.year, now.month, now.day, hour, minute);
      return todayTime.isBefore(now) ? todayTime.add(const Duration(days: 1)) : todayTime;
    }

    // Check for "at X o'clock" or "a las X"
    final RegExp oclockRegex = RegExp(r"(?:at|a las)\s+(\d{1,2})\s*(?:o'clock|pm|am|de la (mañana|tarde|noche))?", caseSensitive: false);
    final oclockMatch = oclockRegex.firstMatch(lowerMessage);
    if (oclockMatch != null) {
      int hour = int.tryParse(oclockMatch.group(1) ?? '') ?? 9;
      final String period = (oclockMatch.group(2) ?? '').toLowerCase();
      
      // Handle Spanish time periods
      if (period.contains('tarde') || period.contains('noche')) {
        if (hour < 12) hour += 12;
      }
      
      final DateTime todayTime = DateTime(now.year, now.month, now.day, hour, 0);
      return todayTime.isBefore(now) ? todayTime.add(const Duration(days: 1)) : todayTime;
    }

    // Default: 1 hour from now if no time detected
    return now.add(const Duration(hours: 1));
  }
}

