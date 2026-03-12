import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import 'auth_service.dart';

/// HTTP client that injects Google auth headers into every request
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._();

  final AuthService _authService = AuthService();
  static const String _timeZone = 'Asia/Ho_Chi_Minh';

  /// Get authenticated Calendar API client
  Future<gcal.CalendarApi?> _getApi() async {
    final headers = await _authService.getGoogleAuthHeaders();
    if (headers == null) return null;
    return gcal.CalendarApi(_GoogleAuthClient(headers));
  }

  /// Check if Google Calendar API is accessible
  Future<bool> isAvailable() async {
    return await _authService.checkGoogleCalendarAvailable();
  }

  /// Test connection to Google Calendar API (returns error message or null on success)
  Future<String?> testConnection() async {
    try {
      final headers = await _authService.getGoogleAuthHeaders();
      if (headers == null) {
        return 'Không lấy được auth headers. Hãy kết nối lại Google Calendar.';
      }

      final api = gcal.CalendarApi(_GoogleAuthClient(headers));
      // Try to list 1 event to test the API
      final events = await api.events.list(
        'primary',
        maxResults: 1,
        timeMin: DateTime.now().toUtc(),
      );
      debugPrint(
        'Google Calendar test: OK, found ${events.items?.length ?? 0} events',
      );
      return null; // Success
    } catch (e) {
      final errStr = e.toString();
      debugPrint('Google Calendar test error: $errStr');
      if (errStr.contains('403') || errStr.contains('forbidden')) {
        return 'Google Calendar API chưa được bật.\n'
            'Vào Google Cloud Console → APIs & Services → '
            'Bật "Google Calendar API" cho project smart-note-2e53e';
      }
      if (errStr.contains('401') || errStr.contains('unauthorized')) {
        return 'Token hết hạn. Hãy ngắt kết nối và kết nối lại Google Calendar.';
      }
      return 'Lỗi kết nối: $errStr';
    }
  }

  // ─── Sync task → Google Calendar ────────────────────────────────────

  /// Create or update a Google Calendar event from a Task.
  /// Returns the Google Calendar event ID.
  Future<String?> syncTask(Task task) async {
    try {
      final api = await _getApi();
      if (api == null) {
        debugPrint('syncTask: Cannot get API client');
        return null;
      }

      final event = _taskToEvent(task);
      debugPrint('syncTask: Syncing "${task.title}" to Google Calendar...');

      if (task.googleEventId != null && task.googleEventId!.isNotEmpty) {
        // Update existing event
        try {
          final updated = await api.events.update(
            event,
            'primary',
            task.googleEventId!,
          );
          debugPrint('syncTask: Updated event ${updated.id}');
          return updated.id;
        } catch (e) {
          // Event may have been deleted on Google side → insert new
          debugPrint('syncTask: Update failed, inserting new: $e');
          final created = await api.events.insert(event, 'primary');
          debugPrint('syncTask: Created new event ${created.id}');
          return created.id;
        }
      } else {
        // Insert new event
        final created = await api.events.insert(event, 'primary');
        debugPrint('syncTask: Created event ${created.id}');
        return created.id;
      }
    } catch (e) {
      debugPrint('syncTask ERROR: $e');
      return null;
    }
  }

  /// Delete an event from Google Calendar
  Future<bool> deleteEvent(String eventId) async {
    try {
      final api = await _getApi();
      if (api == null) return false;
      await api.events.delete('primary', eventId);
      debugPrint('Deleted Google Calendar event: $eventId');
      return true;
    } catch (e) {
      debugPrint('Error deleting Google Calendar event: $e');
      return false;
    }
  }

  // ─── Get events from Google Calendar ────────────────────────────────

  /// Fetch events from Google Calendar for a date range
  Future<List<gcal.Event>> getEvents(DateTime start, DateTime end) async {
    try {
      final api = await _getApi();
      if (api == null) return [];

      final events = await api.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } catch (e) {
      debugPrint('Error getting Google Calendar events: $e');
      return [];
    }
  }

  /// Import Google Calendar events as local Tasks
  Future<List<Task>> importEvents(DateTime start, DateTime end) async {
    final events = await getEvents(start, end);
    final tasks = <Task>[];
    for (final event in events) {
      final task = _eventToTask(event);
      if (task != null) tasks.add(task);
    }
    return tasks;
  }

  /// Sync multiple tasks to Google Calendar.
  /// Returns a map of taskId → googleEventId.
  Future<Map<String, String?>> syncAllTasks(List<Task> tasks) async {
    final results = <String, String?>{};
    for (final task in tasks) {
      final eventId = await syncTask(task);
      results[task.id] = eventId;
    }
    return results;
  }

  // ─── Conversion helpers ─────────────────────────────────────────────

  gcal.Event _taskToEvent(Task task) {
    final event = gcal.Event();
    event.summary = task.title;
    event.description = task.description;

    if (task.type == TaskType.timeBlock &&
        task.startTime != null &&
        task.endTime != null) {
      event.start = gcal.EventDateTime(
        dateTime: task.startTime,
        timeZone: _timeZone,
      );
      event.end = gcal.EventDateTime(
        dateTime: task.endTime,
        timeZone: _timeZone,
      );
    } else {
      // Use deadline as start, +1 hour as end
      event.start = gcal.EventDateTime(
        dateTime: task.deadline,
        timeZone: _timeZone,
      );
      event.end = gcal.EventDateTime(
        dateTime: task.deadline.add(const Duration(hours: 1)),
        timeZone: _timeZone,
      );
    }

    // Recurrence rules
    final recurrence = _buildRecurrence(task);
    if (recurrence != null) {
      event.recurrence = recurrence;
    }

    // Reminder
    event.reminders = gcal.EventReminders(
      useDefault: false,
      overrides: [
        gcal.EventReminder(method: 'popup', minutes: task.reminderMinutes),
      ],
    );

    // Color mapping
    event.colorId = _mapColorToGoogleId(task.color);

    return event;
  }

  Task? _eventToTask(gcal.Event event) {
    if (event.summary == null || event.summary!.isEmpty) return null;

    final start = event.start?.dateTime ?? event.start?.date;
    final end = event.end?.dateTime ?? event.end?.date;
    if (start == null) return null;

    final now = DateTime.now();
    return Task(
      id: 'gcal_${event.id}',
      title: event.summary!,
      description: event.description,
      deadline: start.toLocal(),
      startTime: start.toLocal(),
      endTime: end?.toLocal() ?? start.toLocal().add(const Duration(hours: 1)),
      type: TaskType.timeBlock,
      recurrence: _parseRecurrence(event.recurrence),
      isCompleted: false,
      reminderMinutes: event.reminders?.overrides?.firstOrNull?.minutes ?? 30,
      color: _mapGoogleIdToColor(event.colorId),
      googleEventId: event.id,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ─── Recurrence helpers ─────────────────────────────────────────────

  List<String>? _buildRecurrence(Task task) {
    switch (task.recurrence) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        return ['RRULE:FREQ=DAILY'];
      case RecurrenceType.weekly:
        if (task.recurrenceDays != null && task.recurrenceDays!.isNotEmpty) {
          const dayMap = {
            1: 'MO',
            2: 'TU',
            3: 'WE',
            4: 'TH',
            5: 'FR',
            6: 'SA',
            7: 'SU',
          };
          final days = task.recurrenceDays!
              .map((d) => dayMap[d] ?? 'MO')
              .join(',');
          return ['RRULE:FREQ=WEEKLY;BYDAY=$days'];
        }
        return ['RRULE:FREQ=WEEKLY'];
      case RecurrenceType.monthly:
        return ['RRULE:FREQ=MONTHLY'];
    }
  }

  RecurrenceType _parseRecurrence(List<String>? rules) {
    if (rules == null || rules.isEmpty) return RecurrenceType.none;
    final rule = rules.first.toUpperCase();
    if (rule.contains('DAILY')) return RecurrenceType.daily;
    if (rule.contains('WEEKLY')) return RecurrenceType.weekly;
    if (rule.contains('MONTHLY')) return RecurrenceType.monthly;
    return RecurrenceType.none;
  }

  // ─── Color mapping ──────────────────────────────────────────────────

  /// Map app hex colors to Google Calendar color IDs (1-11)
  String? _mapColorToGoogleId(String? hexColor) {
    if (hexColor == null) return null;
    const colorMap = {
      '#2962FF': '9', // Blueberry
      '#D50000': '11', // Tomato
      '#00C853': '10', // Basil
      '#FF6D00': '6', // Tangerine
      '#AA00FF': '3', // Grape
      '#FFD600': '5', // Banana
    };
    return colorMap[hexColor.toUpperCase()] ?? '9';
  }

  /// Map Google Calendar color IDs back to app hex colors
  String? _mapGoogleIdToColor(String? colorId) {
    const idToColor = {
      '1': '#7986CB', // Lavender
      '2': '#33B679', // Sage
      '3': '#AA00FF', // Grape
      '4': '#E67C73', // Flamingo
      '5': '#FFD600', // Banana
      '6': '#FF6D00', // Tangerine
      '7': '#039BE5', // Peacock
      '8': '#616161', // Graphite
      '9': '#2962FF', // Blueberry
      '10': '#00C853', // Basil
      '11': '#D50000', // Tomato
    };
    return idToColor[colorId] ?? '#2962FF';
  }
}
