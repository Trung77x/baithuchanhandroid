import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../widgets/task_form_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _taskService = TaskService();
  final _notificationService = NotificationService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  List<Task> _allTasks = [];
  List<Task> _selectedDayTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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
      await _taskService.deleteTask(task.id);
      await _notificationService.cancelTaskReminder(task.id);
      await _loadTasks();
    }
  }

  Future<void> _toggleComplete(Task task) async {
    await _taskService.toggleComplete(task);
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch & Deadline'),
        centerTitle: true,
        actions: [
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

              // Delete
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
