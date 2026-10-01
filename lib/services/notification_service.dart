import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:async';
import '../models/task_model.dart';

/// Service for managing local notifications for task reminders.
///
/// Handles scheduling notifications for:
/// - Tasks due in the next hour
/// - Tasks due today (if not already notified)
/// - Tasks due tomorrow
/// - Overdue incomplete tasks
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _periodicCheckTimer;
  final Set<String> _notifiedTaskIds = {}; // Track which tasks we've notified about

  /// Initializes the notification service with platform-specific settings
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Handles notification tap events
  void _onNotificationTapped(NotificationResponse response) {
    // Can be extended to navigate to specific task/course
    print('Notification tapped: ${response.payload}');
  }

  /// Requests notification permissions (required for iOS)
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      await android.requestNotificationsPermission();
    }

    if (ios != null) {
      return await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }

    return true;
  }

  /// Starts periodic checking for upcoming tasks (every 15 minutes)
  void startPeriodicCheck(Stream<List<TaskModel>> tasksStream) {
    // Cancel existing timer if any
    _periodicCheckTimer?.cancel();
    
    // Check immediately
    tasksStream.first.then((tasks) => checkUpcomingTasks(tasks));
    
    // Set up periodic check every 15 minutes
    _periodicCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      tasksStream.first.then((tasks) => checkUpcomingTasks(tasks));
    });
  }

  /// Stops periodic checking
  void stopPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  /// Checks for upcoming tasks and sends appropriate notifications
  Future<void> checkUpcomingTasks(List<TaskModel> tasks) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    
    for (final task in tasks) {
      if (task.dueDate == null || task.isCompleted || task.id == null) continue;
      
      final dueDate = task.dueDate!;
      final difference = dueDate.difference(now);
      
      // Skip if due date is in the past
      if (difference.isNegative) continue;
      
      final taskKey = '${task.id}_${dueDate.millisecondsSinceEpoch}';
      
      // Due in next hour (but more than 5 minutes away)
      if (difference.inMinutes <= 60 && difference.inMinutes > 5) {
        final notificationKey = '${taskKey}_hour';
        if (!_notifiedTaskIds.contains(notificationKey)) {
          await showImmediateNotification(
            id: _getNotificationId(task.id!, 'hour'),
            title: '⏰ Task Due Soon!',
            body: '${task.title} is due in ${difference.inMinutes} minutes',
            payload: 'task:${task.id}:hour',
          );
          _notifiedTaskIds.add(notificationKey);
        }
      }
      
      // Due today (same day, but more than 1 hour away)
      else if (_isSameDay(dueDate, now) && difference.inHours >= 1) {
        final notificationKey = '${taskKey}_today';
        if (!_notifiedTaskIds.contains(notificationKey)) {
          await showImmediateNotification(
            id: _getNotificationId(task.id!, 'today'),
            title: '📅 Task Due Today',
            body: '${task.title} is due today at ${_formatTime(dueDate)}',
            payload: 'task:${task.id}:today',
          );
          _notifiedTaskIds.add(notificationKey);
        }
      }
      
      // Due tomorrow
      else if (_isTomorrow(dueDate, now)) {
        final notificationKey = '${taskKey}_tomorrow';
        if (!_notifiedTaskIds.contains(notificationKey)) {
          await showImmediateNotification(
            id: _getNotificationId(task.id!, 'tomorrow'),
            title: '📚 Task Due Tomorrow',
            body: '${task.title} is due tomorrow at ${_formatTime(dueDate)}',
            payload: 'task:${task.id}:tomorrow',
          );
          _notifiedTaskIds.add(notificationKey);
        }
      }
    }
    
    // Check for overdue tasks
    await checkOverdueTasks(tasks);
  }

  /// Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Helper to check if date1 is tomorrow relative to date2
  bool _isTomorrow(DateTime date1, DateTime date2) {
    final tomorrow = date2.add(const Duration(days: 1));
    return _isSameDay(date1, tomorrow);
  }

  /// Helper to format time
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Shows an immediate notification (for testing or overdue tasks)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming task due dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Cancels all pending notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _notifiedTaskIds.clear();
  }

  /// Generates a unique notification ID from task ID and type
  int _getNotificationId(String taskId, String type) {
    // Create a hash from taskId and type to get a unique int ID
    final combined = '$taskId:$type';
    return combined.hashCode.abs() % 2147483647; // Max int32 value
  }

  /// Checks for overdue tasks and shows notifications
  Future<void> checkOverdueTasks(List<TaskModel> tasks) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    final overdueTasks = tasks.where((task) {
      return task.dueDate != null &&
          task.dueDate!.isBefore(now) &&
          !task.isCompleted;
    }).toList();

    if (overdueTasks.isNotEmpty && !_notifiedTaskIds.contains('overdue_summary')) {
      await showImmediateNotification(
        id: 999999, // Fixed ID for overdue summary
        title: '⚠️ Overdue Tasks',
        body: 'You have ${overdueTasks.length} overdue task(s)',
        payload: 'overdue',
      );
      _notifiedTaskIds.add('overdue_summary');
    }
  }
}
