import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../widgets/task_form_dialog.dart';

class TimeBlockingScreen extends StatefulWidget {
  const TimeBlockingScreen({super.key});

  @override
  State<TimeBlockingScreen> createState() => _TimeBlockingScreenState();
}

class _TimeBlockingScreenState extends State<TimeBlockingScreen> {
  final _taskService = TaskService();
  DateTime _selectedDate = DateTime.now();
  List<Task> _timeBlocks = [];
  bool _isLoading = true;

  // Timeline from 6:00 to 23:00
  static const int _startHour = 6;
  static const int _endHour = 23;
  static const double _hourHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    try {
      final dayTasks = await _taskService.getTasksForDate(_selectedDate);
      _timeBlocks =
          dayTasks
              .where(
                (t) =>
                    t.type == TaskType.timeBlock &&
                    t.startTime != null &&
                    t.endTime != null,
              )
              .toList()
            ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    } catch (e) {
      debugPrint('Error loading time blocks: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return Colors.blue;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  void _prevDay() {
    setState(
      () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
    );
    _loadBlocks();
  }

  void _nextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadBlocks();
  }

  void _goToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadBlocks();
  }

  Future<void> _addBlock({int? hour}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(
        initialDate: _selectedDate,
        task: hour != null
            ? Task(
                id: '',
                title: '',
                deadline: _selectedDate,
                startTime: DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  hour,
                ),
                endTime: DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  hour + 1,
                ),
                type: TaskType.timeBlock,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )
            : null,
      ),
    );

    if (result != null) {
      await _taskService.saveTask(result);
      await _loadBlocks();
    }
  }

  Future<void> _editBlock(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskFormDialog(task: task),
    );

    if (result != null) {
      await _taskService.saveTask(result);
      await _loadBlocks();
    }
  }

  Future<void> _deleteBlock(Task task) async {
    await _taskService.deleteTask(task.id);
    await _loadBlocks();
  }

  double _timeToOffset(DateTime time) {
    final hours = time.hour + time.minute / 60.0;
    return (hours - _startHour) * _hourHeight;
  }

  double _durationHeight(DateTime start, DateTime end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return ((endMinutes - startMinutes) / 60.0) * _hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, dd/MM', 'vi_VN');
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    // Calculate stats
    int totalMinutes = 0;
    for (final block in _timeBlocks) {
      if (block.startTime != null && block.endTime != null) {
        totalMinutes += block.endTime!.difference(block.startTime!).inMinutes;
      }
    }
    final totalHours = totalMinutes / 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Phân bổ thời gian'), centerTitle: true),
      body: Column(
        children: [
          // Date navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevDay,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToday,
                    child: Column(
                      children: [
                        Text(
                          dateFormat.format(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday ? theme.colorScheme.primary : null,
                          ),
                        ),
                        if (isToday)
                          Text(
                            'Hôm nay',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextDay,
                ),
              ],
            ),
          ),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.schedule,
                  label: '${totalHours.toStringAsFixed(1)} giờ',
                  subtitle: 'học tập',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.view_agenda,
                  label: '${_timeBlocks.length}',
                  subtitle: 'khối',
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.check_circle,
                  label: '${_timeBlocks.where((t) => t.isCompleted).length}',
                  subtitle: 'hoàn thành',
                  color: Colors.green,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Timeline
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: SizedBox(
                      height: (_endHour - _startHour) * _hourHeight,
                      child: Stack(
                        children: [
                          // Hour lines
                          ...List.generate(_endHour - _startHour + 1, (i) {
                            final hour = _startHour + i;
                            return Positioned(
                              top: i * _hourHeight,
                              left: 0,
                              right: 0,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    child: Text(
                                      '${hour.toString().padLeft(2, '0')}:00',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      height: 1,
                                      color: Colors.grey[200],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Current time line
                          if (isToday) _buildCurrentTimeLine(),

                          // Tap to add zones
                          ...List.generate(_endHour - _startHour, (i) {
                            final hour = _startHour + i;
                            return Positioned(
                              top: i * _hourHeight,
                              left: 56,
                              right: 8,
                              height: _hourHeight,
                              child: GestureDetector(
                                onTap: () => _addBlock(hour: hour),
                                behavior: HitTestBehavior.translucent,
                                child: const SizedBox.expand(),
                              ),
                            );
                          }),

                          // Time blocks
                          ..._timeBlocks.map((block) => _buildTimeBlock(block)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBlock(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCurrentTimeLine() {
    final now = DateTime.now();
    final top = _timeToOffset(now);
    if (top < 0 || top > (_endHour - _startHour) * _hourHeight) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: 40,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(Task block) {
    if (block.startTime == null || block.endTime == null) {
      return const SizedBox.shrink();
    }

    final top = _timeToOffset(block.startTime!);
    final height = _durationHeight(block.startTime!, block.endTime!);
    final color = _hexToColor(block.color);
    final timeFormat = DateFormat('HH:mm');

    return Positioned(
      top: top.clamp(0, double.infinity),
      left: 56,
      right: 8,
      height: height.clamp(28, double.infinity),
      child: GestureDetector(
        onTap: () => _editBlock(block),
        onLongPress: () => _deleteBlock(block),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: block.isCompleted
                ? color.withOpacity(0.15)
                : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: block.isCompleted ? Colors.grey : color,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (block.isCompleted)
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green[700],
                    ),
                  if (block.isCompleted) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      block.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: block.isCompleted ? Colors.grey : color,
                        decoration: block.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (height > 40)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${timeFormat.format(block.startTime!)} - ${timeFormat.format(block.endTime!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
