import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('tasks');
  }

  /// Lấy tất cả task
  Future<List<Task>> getTasks() async {
    try {
      final collection = _tasksCollection;
      if (collection == null) return [];
      final snapshot = await collection
          .orderBy('deadline', descending: false)
          .get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  /// Lấy task theo ngày
  Future<List<Task>> getTasksForDate(DateTime date) async {
    try {
      final allTasks = await getTasks();
      return allTasks.where((task) {
        // Task trùng ngày deadline
        if (_isSameDay(task.deadline, date)) return true;

        // Task recurring
        if (task.recurrence == RecurrenceType.daily) return true;

        if (task.recurrence == RecurrenceType.weekly &&
            task.recurrenceDays != null) {
          return task.recurrenceDays!.contains(date.weekday);
        }

        if (task.recurrence == RecurrenceType.monthly) {
          return task.deadline.day == date.day;
        }

        // Time block trùng ngày
        if (task.startTime != null && _isSameDay(task.startTime!, date)) {
          return true;
        }

        return false;
      }).toList();
    } catch (e) {
      debugPrint('Error getting tasks for date: $e');
      return [];
    }
  }

  /// Lấy task sắp đến hạn (trong 7 ngày tới)
  Future<List<Task>> getUpcomingTasks() async {
    try {
      final allTasks = await getTasks();
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));
      return allTasks.where((task) {
        return !task.isCompleted &&
            task.deadline.isAfter(now) &&
            task.deadline.isBefore(weekLater);
      }).toList();
    } catch (e) {
      debugPrint('Error getting upcoming tasks: $e');
      return [];
    }
  }

  /// Tạo / cập nhật task
  Future<void> saveTask(Task task) async {
    try {
      final collection = _tasksCollection;
      if (collection == null) return;
      await collection.doc(task.id).set(task.toJson());
    } catch (e) {
      debugPrint('Error saving task: $e');
    }
  }

  /// Xóa task
  Future<void> deleteTask(String taskId) async {
    try {
      final collection = _tasksCollection;
      if (collection == null) return;
      await collection.doc(taskId).delete();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  /// Đánh dấu hoàn thành / chưa hoàn thành
  Future<void> toggleComplete(Task task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now(),
    );
    await saveTask(updated);
  }

  /// Stream real-time tasks
  Stream<List<Task>> tasksStream() {
    final collection = _tasksCollection;
    if (collection == null) return Stream.value([]);
    return collection
        .orderBy('deadline', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Task.fromFirestore(d)).toList());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
