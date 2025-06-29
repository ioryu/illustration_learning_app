import 'package:flutter/material.dart';
import '../models/draw_point.dart';


class TraceOnlyPainter extends CustomPainter {
  final List<DrawPoint?> tracedPoints;
  final Size originalCanvasSize;

  TraceOnlyPainter({
    required this.tracedPoints,
    required this.originalCanvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // キャンバス全体（size）と元のキャンバスサイズ (originalCanvasSize) から
    // 中央に配置するためのオフセット(dx, dy) を計算
    final dx = (size.width - originalCanvasSize.width) / 2;
    final dy = (size.height - originalCanvasSize.height) / 2;
    final offsetCenter = Offset(dx, dy);

    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // tracedPoints に入っている各点を線でつなぐ
    for (int i = 0; i < tracedPoints.length - 1; i++) {
      final p1 = tracedPoints[i];
      final p2 = tracedPoints[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(
          p1.offset! + offsetCenter,
          p2.offset! + offsetCenter,
          redPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}