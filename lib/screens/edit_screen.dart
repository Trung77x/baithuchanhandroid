import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/signature_dialog.dart';

class EditScreen extends StatefulWidget {
  final Note? note;

  const EditScreen({super.key, this.note});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> with WidgetsBindingObserver {
  final NoteService _noteService = NoteService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late Note _currentNote;
  bool _hasChanges = false;
  Timer? _saveTimer;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploading = false;

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
        imageBase64: null,
        signaturePoints: null,
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
    // Read text controller values safely (may be called during dispose)
    String title;
    String content;
    try {
      title = _titleController.text;
      content = _contentController.text;
    } catch (_) {
      // Controllers already disposed, skip save
      return;
    }

    final updatedNote = _currentNote.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    debugPrint(
      'Saving note: id=${updatedNote.id}, title=${updatedNote.title}, '
      'hasImage=${updatedNote.imageBase64 != null}, '
      'hasSignature=${updatedNote.signaturePoints != null}',
    );

    // Update _currentNote so subsequent saves don't lose data
    _currentNote = updatedNote;
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
    // Save synchronously before disposing controllers
    // _handleBackButton already saved, so only save if still needed
    if (_hasChanges || _hasContent) {
      try {
        final note = _currentNote.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          updatedAt: DateTime.now(),
        );
        _noteService.saveNote(note); // fire-and-forget
      } catch (_) {}
    }
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

  Future<void> _pickImageFromSource(ImageSource source) async {
    // Pause auto-save to avoid race conditions
    _saveTimer?.cancel();
    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (imageFile == null) return;

      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Không đọc được ảnh')));
        }
        return;
      }

      // Show loading indicator
      setState(() => _isUploading = true);

      // Upload to Cloudinary
      final cloudinaryUrl = await _cloudinaryService.uploadImage(bytes);

      if (cloudinaryUrl != null) {
        // Store Cloudinary URL (no base64 needed)
        setState(() {
          _currentNote = _currentNote.copyWith(
            imageUrl: cloudinaryUrl,
            imageBase64: null, // clear base64 since we use URL now
          );
          _hasChanges = true;
          _isUploading = false;
        });

        // Persist
        await _noteService.saveNote(
          _currentNote.copyWith(
            title: _titleController.text,
            content: _contentController.text,
            updatedAt: DateTime.now(),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã upload ảnh lên Cloudinary')),
          );
        }
      } else {
        // Fallback: store as base64 locally
        final base64String = base64Encode(bytes);
        setState(() {
          _currentNote = _currentNote.copyWith(imageBase64: base64String);
          _hasChanges = true;
          _isUploading = false;
        });

        await _noteService.saveNote(
          _currentNote.copyWith(
            title: _titleController.text,
            content: _contentController.text,
            updatedAt: DateTime.now(),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload Cloudinary thất bại, đã lưu ảnh cục bộ'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking/capturing image: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi thêm ảnh: $e')));
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Platform.isAndroid || Platform.isIOS)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Chụp ảnh'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Hủy'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSignature() async {
    if (!mounted) return;

    // Pause auto-save to avoid race conditions
    _saveTimer?.cancel();

    final signaturePoints = await showDialog<List<List<double>>?>(
      context: context,
      builder: (BuildContext context) {
        return const SignatureDialog();
      },
    );

    debugPrint('SignatureDialog returned: $signaturePoints');

    if (signaturePoints != null && signaturePoints.isNotEmpty) {
      debugPrint('Signature points count: ${signaturePoints.length}');

      // Update state FIRST to prevent auto-save from overwriting
      setState(() {
        _currentNote = _currentNote.copyWith(signaturePoints: signaturePoints);
        _hasChanges = true;
      });

      // Then persist with latest title/content
      await _noteService.saveNote(
        _currentNote.copyWith(
          title: _titleController.text,
          content: _contentController.text,
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm chữ ký thành công')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chữ ký rỗng')));
      }
    }
  }

  void _removeImage() {
    final updatedNote = _currentNote.copyWith(
      imageBase64: null,
      imageUrl: null,
    );
    _noteService.saveNote(updatedNote);
    setState(() {
      _currentNote = updatedNote;
      _markAsChanged();
    });
  }

  void _removeSignature() {
    final updatedNote = _currentNote.copyWith(signaturePoints: null);
    _noteService.saveNote(updatedNote);
    setState(() {
      _currentNote = updatedNote;
      _markAsChanged();
    });
  }

  Widget _buildImagePreview() {
    // Support both Cloudinary URL and legacy base64
    final hasUrl = _currentNote.imageUrl != null;
    final hasBase64 = _currentNote.imageBase64 != null;

    if (!hasUrl && !hasBase64 && !_isUploading) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;
    if (_isUploading) {
      imageWidget = Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Đang upload lên Cloudinary...'),
            ],
          ),
        ),
      );
    } else if (hasUrl) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _currentNote.imageUrl!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.broken_image, size: 48)),
            );
          },
        ),
      );
    } else {
      try {
        final imageBytes = base64Decode(_currentNote.imageBase64!);
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        debugPrint('Error displaying base64 image: $e');
        return const SizedBox.shrink();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.image, color: Colors.amber[700], size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hình ảnh',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (hasUrl) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cloudinary',
                    style: TextStyle(fontSize: 10, color: Colors.green[800]),
                  ),
                ),
              ],
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: imageWidget,
            ),
            if (!_isUploading)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _removeImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignaturePreview() {
    if (_currentNote.signaturePoints == null ||
        _currentNote.signaturePoints!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.edit_note, color: Colors.blue[700], size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Chữ ký',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.secondaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: SignaturePainter(
                  _currentNote.signaturePoints!,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _removeSignature,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
          title: const Text(
            'Ghi chú',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                const SizedBox(height: 4),
                Divider(color: Colors.grey[300], height: 1),
                const SizedBox(height: 4),
                // Content Input (expanded)
                // Content input; limit max lines so the box returns to a
                // reasonable size after editing long notes. When the user
                // types more than 12 lines the field will scroll internally.
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Nội dung ghi chú của bạn...',
                    hintStyle: TextStyle(fontSize: 16, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 18),
                  keyboardType: TextInputType.multiline,
                  minLines: 6,
                  maxLines: 12,
                ),
                const SizedBox(height: 6),
                // Media Buttons Row - Modern Card Design
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: _showImageOptions,
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: const Text('Ảnh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: _pickSignature,
                          icon: const Icon(Icons.edit_note, size: 20),
                          label: const Text('Chữ ký'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Image Preview
                _buildImagePreview(),
                // Signature Preview
                _buildSignaturePreview(),
                const SizedBox(height: 20),
                // Timestamp Info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Cập nhật: ${_formatDateTime(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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

// Custom painter for rendering signature
class SignaturePainter extends CustomPainter {
  final List<List<double>> points;
  final Color color;

  SignaturePainter(this.points, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (int i = 0; i < points.length - 1; i++) {
      // separator
      if (points[i][0] == -1 && points[i][1] == -1) continue;
      if (points[i + 1][0] == -1 && points[i + 1][1] == -1) continue;

      // points stored normalized 0..1, scale to canvas
      final p1 = Offset(points[i][0] * size.width, points[i][1] * size.height);
      final p2 = Offset(
        points[i + 1][0] * size.width,
        points[i + 1][1] * size.height,
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
