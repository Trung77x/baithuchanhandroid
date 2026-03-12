import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Khởi tạo notification
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // Request permission on Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Lên lịch nhắc nhở trước deadline
  Future<void> scheduleTaskReminder(Task task) async {
    if (!_initialized) await init();

    final reminderTime = task.deadline.subtract(
      Duration(minutes: task.reminderMinutes),
    );

    // Không lên lịch nếu thời gian đã qua
    if (reminderTime.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    await _notifications.zonedSchedule(
      task.id.hashCode,
      'Sắp đến hạn: ${task.title}',
      'Còn ${task.reminderMinutes} phút nữa đến deadline!',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Nhắc nhở deadline',
          channelDescription: 'Thông báo nhắc nhở trước deadline',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2962FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _getDateTimeComponents(task.recurrence),
      payload: task.id,
    );

    debugPrint('Scheduled reminder for "${task.title}" at $scheduledDate');
  }

  /// Lên lịch cho recurring task
  DateTimeComponents? _getDateTimeComponents(RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return DateTimeComponents.time;
      case RecurrenceType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RecurrenceType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RecurrenceType.none:
        return null;
    }
  }

  /// Hủy nhắc nhở cho task
  Future<void> cancelTaskReminder(String taskId) async {
    await _notifications.cancel(taskId.hashCode);
  }

  /// Hủy tất cả nhắc nhở
  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  /// Hiển thị notification ngay lập tức (test)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notifications',
          'Thông báo',
          channelDescription: 'Thông báo tức thời',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Lên lịch nhắc nhở cho tất cả task chưa hoàn thành
  Future<void> scheduleAllReminders(List<Task> tasks) async {
    await cancelAllReminders();
    for (final task in tasks) {
      if (!task.isCompleted) {
        await scheduleTaskReminder(task);
      }
    }
  }
}
