import 'package:flutter/material.dart';
import '../models/draw_point.dart';


class DrawingPainter extends CustomPainter {
  final List<DrawPoint?> points;
  final Color drawColor;
  final double strokeWidth;
  final Offset? eraserPosition;
  final double eraserRadius;
  final Size? originalCanvasSize;

  DrawingPainter(
    this.points, {
    this.drawColor = Colors.red,
    this.strokeWidth = 4.0,
    this.eraserPosition,
    this.eraserRadius = 20.0,
    this.originalCanvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalCanvasSize == null) {
      _drawLines(canvas, size, scaleX: 1, scaleY: 1);
      return;
    }

    final sx = size.width / originalCanvasSize!.width;
    final sy = size.height / originalCanvasSize!.height;
    final scale = sx < sy ? sx : sy;

    final scaledWidth = originalCanvasSize!.width * scale;
    final scaledHeight = originalCanvasSize!.height * scale;

    final dx = (size.width - scaledWidth) / 2;
    final dy = (size.height - scaledHeight) / 2;

    canvas.translate(dx, dy);

    _drawLines(canvas, size, scaleX: scale, scaleY: scale);
  }

  void _drawLines(Canvas canvas, Size size, {required double scaleX, required double scaleY}) {
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null && p1.offset != null && p2.offset != null) {
        final linePaint = Paint()
          ..color = drawColor
          ..strokeWidth = p1.strokeWidth * scaleX
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(p1.offset!.dx * scaleX, p1.offset!.dy * scaleY),
          Offset(p2.offset!.dx * scaleX, p2.offset!.dy * scaleY),
          linePaint,
        );
      }
    }

    if (eraserPosition != null) {
      final eraserPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(eraserPosition!, eraserRadius, eraserPaint);

      final eraserBorderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(eraserPosition!, eraserRadius, eraserBorderPaint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.points != points ||
           oldDelegate.drawColor != drawColor ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.originalCanvasSize != originalCanvasSize;
  }
}