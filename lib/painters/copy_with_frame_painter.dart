import 'package:flutter/material.dart';
import '../models/draw_point.dart';


class CopyWithFramePainter extends CustomPainter {
  final List<DrawPoint?> copiedPoints;
  final Size canvasSize;

  CopyWithFramePainter({
    required this.copiedPoints,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size _) {
    // Path を使って滑らかな線を描画
    Path currentPath = Path();
    Paint? currentPaint;
    bool pathStarted = false;

    for (int i = 0; i < copiedPoints.length; i++) {
      final point = copiedPoints[i];
      
      if (point == null) {
        // nullポイントで線を区切る（ペンを上げた状態）
        if (pathStarted && currentPaint != null) {
          canvas.drawPath(currentPath, currentPaint!);
        }
        currentPath = Path();
        pathStarted = false;
        currentPaint = null;
      } else if (point.offset != null) {
        if (!pathStarted) {
          // 新しい線の開始
          currentPath.moveTo(point.offset!.dx, point.offset!.dy);
          pathStarted = true;
          currentPaint = Paint()
            ..color = Colors.black.withOpacity(0.4)
            ..strokeWidth = point.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
        } else {
          // 線を継続
          currentPath.lineTo(point.offset!.dx, point.offset!.dy);
        }
      }
    }
    
    // 最後の線を描画
    if (pathStarted && currentPaint != null) {
      canvas.drawPath(currentPath, currentPaint!);
    }

    // キャンバスサイズ全体に青枠を描画
    final frameRect = Offset.zero & canvasSize;
    final framePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(frameRect, framePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}