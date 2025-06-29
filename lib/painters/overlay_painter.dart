import 'package:flutter/material.dart';
import '../models/draw_point.dart';


// OverlayPainterも同様にPath方式で修正
class OverlayPainter extends CustomPainter {
  final List<DrawPoint?> tracedPoints;
  final List<DrawPoint?> copiedPoints;
  final Size originalCanvasSize;

  OverlayPainter({
    required this.tracedPoints,
    required this.copiedPoints,
    required this.originalCanvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dx = (size.width - originalCanvasSize.width) / 2;
    final dy = (size.height - originalCanvasSize.height) / 2;
    final offsetCenter = Offset(dx, dy);

    // 赤色（トレス線）をPath方式で描画
    _drawPointsWithPath(canvas, tracedPoints, Colors.red, offsetCenter);

    // 黒色（模写線・半透明）をPath方式で描画
    _drawPointsWithPath(canvas, copiedPoints, Colors.black.withOpacity(0.4), offsetCenter);
  }

  void _drawPointsWithPath(Canvas canvas, List<DrawPoint?> points, Color color, Offset offsetCenter) {
    Path currentPath = Path();
    Paint? currentPaint;
    bool pathStarted = false;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      if (point == null) {
        // nullポイントで線を区切る
        if (pathStarted && currentPaint != null) {
          canvas.drawPath(currentPath, currentPaint!);
        }
        currentPath = Path();
        pathStarted = false;
        currentPaint = null;
      } else if (point.offset != null) {
        final adjustedOffset = point.offset! + offsetCenter;
        
        if (!pathStarted) {
          // 新しい線の開始
          currentPath.moveTo(adjustedOffset.dx, adjustedOffset.dy);
          pathStarted = true;
          currentPaint = Paint()
            ..color = color
            ..strokeWidth = point.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
        } else {
          // 線を継続
          currentPath.lineTo(adjustedOffset.dx, adjustedOffset.dy);
        }
      }
    }
    
    // 最後の線を描画
    if (pathStarted && currentPaint != null) {
      canvas.drawPath(currentPath, currentPaint!);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}