import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Minimal command console scanning indicator.
/// Uses an industrial bracket frame with a sweeping telemetry laser line.
///
/// Adheres strictly to design constraints:
/// - Zero spinner clichés
/// - Zero neon glow
/// - Zero bouncy animations
/// - Clean dark console aesthetic
class ScanningIndicator extends StatefulWidget {
  final double size;

  const ScanningIndicator({
    super.key,
    this.size = 56.0,
  });

  @override
  State<ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<ScanningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _scanAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConsoleScanPainter(
              progress: _scanAnimation.value,
              borderColor: palette.border,
              scannerColor: palette.textPrimary,
              cornerColor: palette.textMuted,
            ),
          );
        },
      ),
    );
  }
}

class _ConsoleScanPainter extends CustomPainter {
  final double progress;
  final Color borderColor;
  final Color scannerColor;
  final Color cornerColor;

  _ConsoleScanPainter({
    required this.progress,
    required this.borderColor,
    required this.scannerColor,
    required this.cornerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Outer box frame
    final framePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), framePaint);

    // 2. Corner markers
    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const cornerLen = 6.0;
    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLen, 0), cornerPaint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(0, h), Offset(cornerLen, h), cornerPaint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - cornerLen, h), cornerPaint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLen), cornerPaint);

    // 3. Sweeping horizontal scanner line
    final scanY = 4.0 + (h - 8.0) * progress;
    final scanPaint = Paint()
      ..color = scannerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(4.0, scanY), Offset(w - 4.0, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(_ConsoleScanPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
