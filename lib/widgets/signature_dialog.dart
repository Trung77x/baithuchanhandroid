import 'package:flutter/material.dart';

/// SignatureDialog
/// - captures strokes as normalized points (0..1) so they can be scaled
/// - provides clear + save actions
class SignatureDialog extends StatefulWidget {
  final List<List<double>>? initialSignature;

  const SignatureDialog({super.key, this.initialSignature});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  // normalized points (0..1). Use Offset(-1,-1) as stroke separator
  final List<Offset> _points = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSignature != null) {
      _points.clear();
      for (final p in widget.initialSignature!) {
        _points.add(Offset(p[0].toDouble(), p[1].toDouble()));
      }
    }
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  void _saveSignature() {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng vẽ chữ ký')));
      return;
    }

    final signature = <List<double>>[];
    for (final o in _points) {
      signature.add([o.dx, o.dy]);
    }

    Navigator.of(context).pop(signature);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF06A77D), Color(0xFF048860)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.edit, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Vẽ chữ ký',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Canvas
              SizedBox(
                height: 260,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (ev) {
                          final local = ev.localPosition;
                          final nx = (constraints.maxWidth > 0)
                              ? (local.dx / constraints.maxWidth).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          final ny = (constraints.maxHeight > 0)
                              ? (local.dy / constraints.maxHeight).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          debugPrint(
                            'SignatureDialog onPointerDown: ($nx, $ny)',
                          );
                          setState(() => _points.add(Offset(nx, ny)));
                        },
                        onPointerMove: (ev) {
                          final local = ev.localPosition;
                          final nx = (constraints.maxWidth > 0)
                              ? (local.dx / constraints.maxWidth).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          final ny = (constraints.maxHeight > 0)
                              ? (local.dy / constraints.maxHeight).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          debugPrint(
                            'SignatureDialog onPointerMove: ($nx, $ny)',
                          );
                          setState(() => _points.add(Offset(nx, ny)));
                        },
                        onPointerUp: (_) =>
                            setState(() => _points.add(const Offset(-1, -1))),
                        child: CustomPaint(
                          painter: _DialogSignaturePainter(_points),
                          size: Size.infinite,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _clearSignature,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _saveSignature,
                      icon: const Icon(Icons.check),
                      label: const Text('Lưu chữ ký'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06A77D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSignaturePainter extends CustomPainter {
  final List<Offset> points; // normalized 0..1 plus separators

  _DialogSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF06A77D)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (int i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final q = points[i + 1];
      if (p.dx == -1 && p.dy == -1) continue;
      if (q.dx == -1 && q.dy == -1) continue;
      final p1 = Offset(p.dx * size.width, p.dy * size.height);
      final p2 = Offset(q.dx * size.width, q.dy * size.height);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialogSignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
