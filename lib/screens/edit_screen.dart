import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/note_model.dart';
import '../services/note_service.dart';

class EditScreen extends StatefulWidget {
  final Note? note;

  const EditScreen({super.key, this.note});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> with WidgetsBindingObserver {
  final NoteService _noteService = NoteService();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late Note _currentNote;
  bool _hasChanges = false;
  Timer? _saveTimer;

  bool get _hasContent {
    return _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.note != null) {
      _currentNote = widget.note!;
      _titleController = TextEditingController(text: _currentNote.title);
      _contentController = TextEditingController(text: _currentNote.content);
    } else {
      _currentNote = Note(
        id: const Uuid().v4(),
        title: '',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _titleController = TextEditingController();
      _contentController = TextEditingController();
    }

    _titleController.addListener(() {
      _markAsChanged();
      _updateState();
      _scheduleAutoSave();
    });
    _contentController.addListener(() {
      _markAsChanged();
      _updateState();
      _scheduleAutoSave();
    });
  }

  void _markAsChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  void _updateState() {
    setState(() {
      // used to refresh save button state when content changes
    });
  }

  Future<void> _saveNote() async {
    final updatedNote = _currentNote.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );

    await _noteService.saveNote(updatedNote);
    _hasChanges = false;
  }

  Future<void> _handleBackButton(BuildContext context) async {
    if (!mounted) return;

    // Auto-save before leaving; save if user typed anything
    if (_hasChanges || _hasContent) {
      await _saveNote();
    }

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _autoSave();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    // debounce saves while typing to persist quickly without spamming
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () async {
      if (_hasChanges || _hasContent) {
        await _saveNote();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBackButton(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ghi chú'),
          backgroundColor: Colors.blue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackButton(context),
          ),
          // actions removed: auto-save + back button handle persistence
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Input
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Tiêu đề...',
                    hintStyle: TextStyle(fontSize: 20, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 16),
                // Content Input
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Nội dung ghi chú của bạn...',
                    hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 16),
                  maxLines: null,
                  expands: false,
                ),
                const SizedBox(height: 32),
                // Timestamp Info
                Text(
                  'Lần cập nhật cuối: ${_formatDateTime(DateTime.now())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _autoSave();
    }
  }

  Future<void> _autoSave() async {
    if (_hasChanges || _hasContent) {
      await _saveNote();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
