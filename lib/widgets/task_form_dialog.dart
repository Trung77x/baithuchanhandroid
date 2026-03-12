import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? task;
  final DateTime? initialDate;

  const TaskFormDialog({super.key, this.task, this.initialDate});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _deadline;
  TimeOfDay _deadlineTime = const TimeOfDay(hour: 23, minute: 59);
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TaskType _taskType = TaskType.deadline;
  RecurrenceType _recurrence = RecurrenceType.none;
  final Set<int> _recurrenceDays = {};
  int _reminderMinutes = 30;
  String _selectedColor = '#2962FF';

  final List<Map<String, dynamic>> _colorOptions = [
    {'color': '#2962FF', 'name': 'Xanh dương'},
    {'color': '#D50000', 'name': 'Đỏ'},
    {'color': '#00C853', 'name': 'Xanh lá'},
    {'color': '#FF6D00', 'name': 'Cam'},
    {'color': '#AA00FF', 'name': 'Tím'},
    {'color': '#FFD600', 'name': 'Vàng'},
  ];

  final List<Map<String, dynamic>> _reminderOptions = [
    {'minutes': 5, 'label': '5 phút trước'},
    {'minutes': 10, 'label': '10 phút trước'},
    {'minutes': 15, 'label': '15 phút trước'},
    {'minutes': 30, 'label': '30 phút trước'},
    {'minutes': 60, 'label': '1 giờ trước'},
    {'minutes': 120, 'label': '2 giờ trước'},
    {'minutes': 1440, 'label': '1 ngày trước'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      final t = widget.task!;
      _titleController.text = t.title;
      _descController.text = t.description ?? '';
      _deadline = t.deadline;
      _deadlineTime = TimeOfDay(
        hour: t.deadline.hour,
        minute: t.deadline.minute,
      );
      _taskType = t.type;
      _recurrence = t.recurrence;
      if (t.recurrenceDays != null) _recurrenceDays.addAll(t.recurrenceDays!);
      _reminderMinutes = t.reminderMinutes;
      _selectedColor = t.color ?? '#2962FF';
      if (t.startTime != null) {
        _startTime = TimeOfDay(
          hour: t.startTime!.hour,
          minute: t.startTime!.minute,
        );
      }
      if (t.endTime != null) {
        _endTime = TimeOfDay(hour: t.endTime!.hour, minute: t.endTime!.minute);
      }
    } else {
      _deadline = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _pickTime(String which) async {
    final initial = which == 'deadline'
        ? _deadlineTime
        : which == 'start'
        ? _startTime ?? const TimeOfDay(hour: 8, minute: 0)
        : _endTime ?? const TimeOfDay(hour: 9, minute: 0);

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (which == 'deadline') {
          _deadlineTime = picked;
        } else if (which == 'start') {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tiêu đề')));
      return;
    }

    final fullDeadline = DateTime(
      _deadline.year,
      _deadline.month,
      _deadline.day,
      _deadlineTime.hour,
      _deadlineTime.minute,
    );

    DateTime? startDateTime;
    DateTime? endDateTime;
    if (_taskType == TaskType.timeBlock &&
        _startTime != null &&
        _endTime != null) {
      startDateTime = DateTime(
        _deadline.year,
        _deadline.month,
        _deadline.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      endDateTime = DateTime(
        _deadline.year,
        _deadline.month,
        _deadline.day,
        _endTime!.hour,
        _endTime!.minute,
      );
    }

    final now = DateTime.now();
    final List<int>? days =
        _recurrence == RecurrenceType.weekly && _recurrenceDays.isNotEmpty
        ? (_recurrenceDays.toList()..sort())
        : null;
    final task = Task(
      id: widget.task?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      deadline: fullDeadline,
      startTime: startDateTime,
      endTime: endDateTime,
      type: _taskType,
      recurrence: _recurrence,
      recurrenceDays: days,
      isCompleted: widget.task?.isCompleted ?? false,
      reminderMinutes: _reminderMinutes,
      color: _selectedColor,
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.task_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.task != null ? 'Sửa công việc' : 'Tạo công việc mới',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Tiêu đề *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),

            // Task Type
            const Text(
              'Loại công việc',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskType>(
              segments: const [
                ButtonSegment(
                  value: TaskType.deadline,
                  label: Text('Deadline'),
                  icon: Icon(Icons.flag),
                ),
                ButtonSegment(
                  value: TaskType.study,
                  label: Text('Lịch học'),
                  icon: Icon(Icons.school),
                ),
                ButtonSegment(
                  value: TaskType.timeBlock,
                  label: Text('Thời gian'),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {_taskType},
              onSelectionChanged: (set) =>
                  setState(() => _taskType = set.first),
            ),
            const SizedBox(height: 16),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ngày',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(dateFormat.format(_deadline)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime('deadline'),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Giờ deadline',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.access_time),
                      ),
                      child: Text(_deadlineTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time Block start/end
            if (_taskType == TaskType.timeBlock) ...[
              const Text(
                'Khối thời gian học tập',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime('start'),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Bắt đầu',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.play_arrow),
                        ),
                        child: Text(_startTime?.format(context) ?? 'Chọn'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime('end'),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Kết thúc',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.stop),
                        ),
                        child: Text(_endTime?.format(context) ?? 'Chọn'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Recurrence
            const Text(
              'Lặp lại',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RecurrenceType>(
              segments: const [
                ButtonSegment(value: RecurrenceType.none, label: Text('Không')),
                ButtonSegment(value: RecurrenceType.daily, label: Text('Ngày')),
                ButtonSegment(
                  value: RecurrenceType.weekly,
                  label: Text('Tuần'),
                ),
                ButtonSegment(
                  value: RecurrenceType.monthly,
                  label: Text('Tháng'),
                ),
              ],
              selected: {_recurrence},
              onSelectionChanged: (set) =>
                  setState(() => _recurrence = set.first),
            ),
            const SizedBox(height: 8),

            // Weekly day picker
            if (_recurrence == RecurrenceType.weekly) ...[
              const Text(
                'Chọn các ngày trong tuần:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: Task.weekDayNames.entries.map((entry) {
                  final selected = _recurrenceDays.contains(entry.key);
                  return FilterChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _recurrenceDays.add(entry.key);
                        } else {
                          _recurrenceDays.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Reminder
            const Text(
              'Nhắc nhở trước',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _reminderMinutes,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.notifications_active),
              ),
              items: _reminderOptions
                  .map(
                    (opt) => DropdownMenuItem<int>(
                      value: opt['minutes'] as int,
                      child: Text(opt['label'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _reminderMinutes = val);
              },
            ),
            const SizedBox(height: 12),

            // Color
            const Text(
              'Màu sắc',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colorOptions.map((opt) {
                final hex = opt['color'] as String;
                final isSelected = hex == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
