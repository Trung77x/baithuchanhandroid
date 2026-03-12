import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../services/google_calendar_service.dart';
import '../services/auth_service.dart';
import '../widgets/task_form_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _taskService = TaskService();
  final _notificationService = NotificationService();
  final _gcalService = GoogleCalendarService();
  final _authService = AuthService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  List<Task> _allTasks = [];
  List<Task> _selectedDayTasks = [];
  bool _isLoading = true;
  bool _isGoogleConnected = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkGoogleConnection();
  }

  Future<void> _checkGoogleConnection() async {
    final connected = await _authService.checkGoogleCalendarAvailable();
    if (mounted) setState(() => _isGoogleConnected = connected);
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      _allTasks = await _taskService.getTasks();
      _selectedDayTasks = await _taskService.getTasksForDate(_selectedDay);
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTasksForDay(DateTime day) async {
    _selectedDayTasks = await _taskService.getTasksForDate(day);
    if (mounted) setState(() {});
  }

  List<Task> _getEventsForDay(DateTime day) {
    return _allTasks.where((task) {
      if (task.deadline.year == day.year &&
          task.deadline.month == day.month &&
          task.deadline.day == day.day) {
        return true;
      }
      if (task.recurrence == RecurrenceType.daily) return true;
      if (task.recurrence == RecurrenceType.weekly &&
          task.recurrenceDays != null &&
          task.recurrenceDays!.contains(day.weekday)) {
        return true;
      }
      if (task.recurrence == RecurrenceType.monthly &&
          task.deadline.day == day.day) {
        return true;
      }
      return false;
    }).toList();
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return Colors.blue;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Future<void> _addOrEditTask({Task? task}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) =>
          TaskFormDialog(task: task, initialDate: _selectedDay),
    );

    if (result != null) {
      await _taskService.saveTask(result);
      await _notificationService.scheduleTaskReminder(result);

      // Auto-sync to Google Calendar if connected
      if (_isGoogleConnected) {
        final eventId = await _gcalService.syncTask(result);
        if (eventId != null && eventId != result.googleEventId) {
          final synced = result.copyWith(
            googleEventId: eventId,
            updatedAt: DateTime.now(),
          );
          await _taskService.saveTask(synced);
        }
      }

      await _loadTasks();
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: Text('Bạn có chắc muốn xóa "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Delete from Google Calendar too
      if (task.googleEventId != null && _isGoogleConnected) {
        await _gcalService.deleteEvent(task.googleEventId!);
      }
      await _taskService.deleteTask(task.id);
      await _notificationService.cancelTaskReminder(task.id);
      await _loadTasks();
    }
  }

  Future<void> _toggleComplete(Task task) async {
    await _taskService.toggleComplete(task);
    await _loadTasks();
  }

  // ─── Google Calendar methods ──────────────────────────────────────

  void _showGoogleCalendarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Google Calendar',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!_isGoogleConnected) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Kết nối Google Calendar để đồng bộ lịch và sự kiện',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _connectGoogle();
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Kết nối Google Calendar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                  title: const Text('Đồng bộ tất cả lên Google Calendar'),
                  subtitle: const Text('Đẩy tất cả công việc lên Google'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _syncAllToGoogle();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.cloud_download,
                    color: Colors.green,
                  ),
                  title: const Text('Nhập sự kiện từ Google Calendar'),
                  subtitle: const Text('Tải sự kiện tháng này về ứng dụng'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importFromGoogle();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green[400]),
                  title: const Text('Đã kết nối'),
                  subtitle: const Text('Công việc mới sẽ tự động đồng bộ'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _connectGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final ok = await _authService.requestCalendarAccess();
      if (ok) {
        setState(() => _isGoogleConnected = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã kết nối Google Calendar thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể kết nối Google Calendar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error connecting Google Calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _syncAllToGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final results = await _gcalService.syncAllTasks(_allTasks);
      int synced = 0;
      for (final entry in results.entries) {
        if (entry.value != null) {
          final task = _allTasks.firstWhere((t) => t.id == entry.key);
          if (task.googleEventId != entry.value) {
            await _taskService.saveTask(
              task.copyWith(
                googleEventId: entry.value,
                updatedAt: DateTime.now(),
              ),
            );
          }
          synced++;
        }
      }
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã đồng bộ $synced/${_allTasks.length} công việc lên Google Calendar',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error syncing all tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _importFromGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDayOfMonth = DateTime(
        _focusedDay.year,
        _focusedDay.month + 1,
        0,
        23,
        59,
        59,
      );

      final events = await _gcalService.importEvents(
        firstDayOfMonth,
        lastDayOfMonth,
      );

      int imported = 0;
      for (final task in events) {
        // Skip if already imported (check by googleEventId)
        final existingTasks = _allTasks.where(
          (t) => t.googleEventId == task.googleEventId,
        );
        if (existingTasks.isEmpty) {
          await _taskService.saveTask(task);
          imported++;
        }
      }

      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported > 0
                  ? 'Đã nhập $imported sự kiện từ Google Calendar'
                  : 'Không có sự kiện mới để nhập',
            ),
            backgroundColor: imported > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing from Google Calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nhập sự kiện: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch & Deadline'),
        centerTitle: true,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _isGoogleConnected ? Icons.cloud_done : Icons.cloud_outlined,
                color: _isGoogleConnected ? Colors.green : null,
              ),
              tooltip: 'Google Calendar',
              onPressed: _showGoogleCalendarOptions,
            ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Hôm nay',
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
              _loadTasksForDay(DateTime.now());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          TableCalendar<Task>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadTasksForDay(selectedDay);
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            locale: 'vi_VN',
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markerMargin: const EdgeInsets.symmetric(horizontal: 1),
            ),
          ),

          const Divider(height: 1),

          // Selected day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.event_note,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_selectedDay),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedDayTasks.length} việc',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Task list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedDayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không có công việc nào',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _addOrEditTask(),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm công việc'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _selectedDayTasks.length,
                    itemBuilder: (context, index) {
                      final task = _selectedDayTasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditTask(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final taskColor = _hexToColor(task.color);
    final isOverdue =
        !task.isCompleted && task.deadline.isBefore(DateTime.now());
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addOrEditTask(task: task),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: taskColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => _toggleComplete(task),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted ? taskColor : Colors.transparent,
                    border: Border.all(color: taskColor, width: 2),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type icon
                        Icon(task.type.icon, size: 16, color: taskColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(task.deadline),
                          style: TextStyle(
                            fontSize: 13,
                            color: isOverdue ? Colors.red : Colors.grey[600],
                            fontWeight: isOverdue
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (task.type == TaskType.timeBlock &&
                            task.startTime != null &&
                            task.endTime != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: taskColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${timeFormat.format(task.startTime!)} - ${timeFormat.format(task.endTime!)}',
                              style: TextStyle(fontSize: 11, color: taskColor),
                            ),
                          ),
                        ],
                        if (task.recurrence != RecurrenceType.none) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            task.recurrence.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),

              // Google Calendar indicator + Delete
              if (task.googleEventId != null)
                Tooltip(
                  message: 'Đã đồng bộ Google Calendar',
                  child: Icon(
                    Icons.cloud_done,
                    size: 18,
                    color: Colors.green[400],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey,
                onPressed: () => _deleteTask(task),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
