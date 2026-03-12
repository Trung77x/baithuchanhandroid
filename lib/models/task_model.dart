import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Loại lặp lại
enum RecurrenceType {
  none, // Không lặp
  daily, // Hàng ngày
  weekly, // Hàng tuần
  monthly, // Hàng tháng
}

extension RecurrenceTypeExt on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.none:
        return 'Không lặp';
      case RecurrenceType.daily:
        return 'Hàng ngày';
      case RecurrenceType.weekly:
        return 'Hàng tuần';
      case RecurrenceType.monthly:
        return 'Hàng tháng';
    }
  }
}

/// Loại task
enum TaskType {
  deadline, // Deadline bài tập / thi
  study, // Lịch học
  timeBlock, // Khối thời gian học tập
}

extension TaskTypeExt on TaskType {
  IconData get icon {
    switch (this) {
      case TaskType.deadline:
        return Icons.flag;
      case TaskType.study:
        return Icons.school;
      case TaskType.timeBlock:
        return Icons.schedule;
    }
  }
}

class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime deadline; // Ngày + giờ deadline
  final DateTime? startTime; // Giờ bắt đầu (cho time blocking)
  final DateTime? endTime; // Giờ kết thúc (cho time blocking)
  final TaskType type;
  final RecurrenceType recurrence;
  final List<int>? recurrenceDays; // Ngày trong tuần (1=T2..7=CN) cho weekly
  final bool isCompleted;
  final int reminderMinutes; // Nhắc trước deadline bao nhiêu phút
  final String? color; // Mã màu hex
  final String? googleEventId; // ID sự kiện Google Calendar
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.deadline,
    this.startTime,
    this.endTime,
    this.type = TaskType.deadline,
    this.recurrence = RecurrenceType.none,
    this.recurrenceDays,
    this.isCompleted = false,
    this.reminderMinutes = 30,
    this.color,
    this.googleEventId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.name,
      'recurrence': recurrence.name,
      'recurrenceDays': recurrenceDays,
      'isCompleted': isCompleted,
      'reminderMinutes': reminderMinutes,
      'color': color,
      'googleEventId': googleEventId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: DateTime.parse(json['deadline'] as String),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      type: TaskType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TaskType.deadline,
      ),
      recurrence: RecurrenceType.values.firstWhere(
        (e) => e.name == json['recurrence'],
        orElse: () => RecurrenceType.none,
      ),
      recurrenceDays: json['recurrenceDays'] != null
          ? List<int>.from(json['recurrenceDays'] as List)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      reminderMinutes: json['reminderMinutes'] as int? ?? 30,
      color: json['color'] as String?,
      googleEventId: json['googleEventId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Task.fromJson(data);
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? deadline,
    DateTime? startTime,
    DateTime? endTime,
    TaskType? type,
    RecurrenceType? recurrence,
    List<int>? recurrenceDays,
    bool? isCompleted,
    int? reminderMinutes,
    String? color,
    String? googleEventId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      color: color ?? this.color,
      googleEventId: googleEventId ?? this.googleEventId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Lấy tên loại task bằng tiếng Việt
  String get typeLabel {
    switch (type) {
      case TaskType.deadline:
        return 'Deadline';
      case TaskType.study:
        return 'Lịch học';
      case TaskType.timeBlock:
        return 'Khối thời gian';
    }
  }

  /// Lấy tên loại lặp lại bằng tiếng Việt
  String get recurrenceLabel {
    switch (recurrence) {
      case RecurrenceType.none:
        return 'Không lặp';
      case RecurrenceType.daily:
        return 'Hàng ngày';
      case RecurrenceType.weekly:
        return 'Hàng tuần';
      case RecurrenceType.monthly:
        return 'Hàng tháng';
    }
  }

  /// Kiểm tra task có quá hạn không
  bool get isOverdue => !isCompleted && deadline.isBefore(DateTime.now());

  /// Tên các ngày trong tuần cho recurring
  static const Map<int, String> weekDayNames = {
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
    7: 'CN',
  };
}
