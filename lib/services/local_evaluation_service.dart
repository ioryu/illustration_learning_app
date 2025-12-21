import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/draw_point.dart';
import '../repositories/local_history_repository.dart';

class LocalEvaluationService {
  final LocalHistoryRepository historyRepository;

  LocalEvaluationService(this.historyRepository);

  Future<Map<String, dynamic>> evaluate({
    required List<DrawPoint?> tracedPoints,
    required List<DrawPoint?> copiedPoints,
    required Size originalSize,
    required Offset adjustedPosition,
    required double adjustedScale,
    required String uuid,
  }) async {
    if (originalSize.width <= 0 || originalSize.height <= 0) {
      throw Exception('Invalid originalSize');
    }

    final traced = tracedPoints.whereType<DrawPoint>().toList();
    final copied = copiedPoints.whereType<DrawPoint>().toList();

    final totalScore = await _evaluateCore(
      tracedPoints: traced,
      copiedPoints: copied,
      dx: adjustedPosition.dx,
      dy: adjustedPosition.dy,
      scale: adjustedScale,
      canvasSize: originalSize,
    );

    await historyRepository.saveEvaluationResult(
      uuid: uuid,
      totalScore: totalScore,
    );
    print('保存するデータ: uuid=$uuid, totalScore=$totalScore');

    return {
      'message': '評価完了',
      'score': totalScore,
    };
  }

  Future<double> _evaluateCore({
    required List<DrawPoint> tracedPoints,
    required List<DrawPoint> copiedPoints,
    required double dx,
    required double dy,
    required double scale,
    required Size canvasSize,
  }) async {
    // ----------------------------
    // 1. マスク作成（線幅2に変更）
    // ----------------------------
    final tracedMask = _createMask(tracedPoints, canvasSize, scale: 1.0, offset: Offset.zero, lineWidth: 2);
    final copiedMask = _createMask(copiedPoints, canvasSize, scale: scale, offset: Offset(dx, dy), lineWidth: 2);

    // ----------------------------
    // 2. 膨張処理（Python近似）
    // ----------------------------
    final dilatedTraced = _dilate(tracedMask, 10); // radiusを大きく
    final dilatedCopied = _dilate(copiedMask, 10);

    // ----------------------------
    // 3. IoU
    // ----------------------------
    final iouScore = _maskIoU(dilatedTraced, dilatedCopied);

    // ----------------------------
    // 4. Skeleton化
    // ----------------------------
    final tracedSkel = _skeletonize(tracedMask);
    final copiedSkel = _skeletonize(copiedMask);

    // ----------------------------
    // 5. Skeleton類似度（簡易SSIM近似）
    // ----------------------------
    final ssimScore = _maskSSIM(tracedSkel, copiedSkel);

    // ----------------------------
    // 6. Shape Score（輪郭距離比で近似）
    // ----------------------------
    final shapeScore = _calculateShapeScoreAdvanced(tracedMask, copiedMask);

    // ----------------------------
    // 7. 合成
    // ----------------------------
    const wIou = 0.3;
    const wSsim = 0.4;
    const wShape = 0.3;
    double total = wIou * iouScore + wSsim * ssimScore + wShape * shapeScore;
    total = (total * 100).clamp(0.0, 100.0);
    return double.parse(total.toStringAsFixed(2));
  }

  // ----------------------------
  // マスク生成（線幅可変）
  // ----------------------------
  List<List<int>> _createMask(
      List<DrawPoint> points, Size size,
      {double scale = 1.0, Offset offset = Offset.zero, int lineWidth = 2}) {
    final mask = List.generate(size.height.toInt(),
        (_) => List<int>.filled(size.width.toInt(), 0));

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 == null || p2 == null) continue;
      final x1 = (p1.offset.dx * scale + offset.dx).round();
      final y1 = (p1.offset.dy * scale + offset.dy).round();
      final x2 = (p2.offset.dx * scale + offset.dx).round();
      final y2 = (p2.offset.dy * scale + offset.dy).round();
      _drawLineOnMask(mask, x1, y1, x2, y2, lineWidth: lineWidth);
    }
    return mask;
  }

  void _drawLineOnMask(List<List<int>> mask, int x0, int y0, int x1, int y1, {int lineWidth = 2}) {
    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;
    int x = x0, y = y0;
    while (true) {
      for (int lx = -lineWidth ~/ 2; lx <= lineWidth ~/ 2; lx++) {
        for (int ly = -lineWidth ~/ 2; ly <= lineWidth ~/ 2; ly++) {
          int nx = x + lx;
          int ny = y + ly;
          if (ny >= 0 && ny < mask.length && nx >= 0 && nx < mask[0].length) {
            mask[ny][nx] = 1;
          }
        }
      }
      if (x == x1 && y == y1) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  // ----------------------------
  // 膨張処理（radiusピクセル範囲を1にする）
  // ----------------------------
  List<List<int>> _dilate(List<List<int>> mask, int radius) {
    final height = mask.length;
    final width = mask[0].length;
    final newMask = List.generate(height, (_) => List<int>.from(mask[0]));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y][x] == 1) {
          for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
              int ny = y + dy;
              int nx = x + dx;
              if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
                newMask[ny][nx] = 1;
              }
            }
          }
        }
      }
    }
    return newMask;
  }

  // ----------------------------
  // Skeleton化（簡易、線幅1に）
  // ----------------------------
  List<List<int>> _skeletonize(List<List<int>> mask) {
    final height = mask.length;
    final width = mask[0].length;
    final skel = List.generate(height, (_) => List<int>.filled(width, 0));
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (mask[y][x] == 1) {
          int sum = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              sum += mask[y + dy][x + dx];
            }
          }
          if (sum > 0) skel[y][x] = 1;
        }
      }
    }
    return skel;
  }

  // ----------------------------
  // Skeleton類似度（3x3局所一致率でSSIM近似）
  // ----------------------------
  double _maskSSIM(List<List<int>> mask1, List<List<int>> mask2) {
    final height = mask1.length;
    final width = mask1[0].length;
    int match = 0;
    int total = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        bool val1 = false, val2 = false;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            int ny = y + dy;
            int nx = x + dx;
            if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
              if (mask1[ny][nx] == 1) val1 = true;
              if (mask2[ny][nx] == 1) val2 = true;
            }
          }
        }
        if (val1 || val2) {
          total++;
          if (val1 == val2) match++;
        }
      }
    }
    if (total == 0) return 0.0;
    return match / total;
  }

  // ----------------------------
  // Shape Score（輪郭距離比で近似）
  // ----------------------------
  double _calculateShapeScoreAdvanced(List<List<int>> mask1, List<List<int>> mask2) {
    final pts1 = _extractContourPoints(mask1);
    final pts2 = _extractContourPoints(mask2);
    if (pts1.isEmpty || pts2.isEmpty) return 0.0;

    double totalDist1 = 0.0;
    for (final p in pts1) {
      double minDist = pts2.map((q) => _distance(p, q)).reduce(min);
      totalDist1 += minDist;
    }
    double avgDist1 = totalDist1 / pts1.length;

    double totalDist2 = 0.0;
    for (final p in pts2) {
      double minDist = pts1.map((q) => _distance(p, q)).reduce(min);
      totalDist2 += minDist;
    }
    double avgDist2 = totalDist2 / pts2.length;

    double score = 1 / (1 + (avgDist1 + avgDist2) / 2);
    return score.clamp(0.0, 1.0);
  }

  List<Offset> _extractContourPoints(List<List<int>> mask) {
    final points = <Offset>[];
    final h = mask.length;
    final w = mask[0].length;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        if (mask[y][x] == 1) {
          bool isEdge = false;
          for (int dy = -1; dy <= 1 && !isEdge; dy++) {
            for (int dx = -1; dx <= 1 && !isEdge; dx++) {
              if (mask[y + dy][x + dx] == 0) isEdge = true;
            }
          }
          if (isEdge) points.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    return points;
  }

  double _distance(Offset a, Offset b) {
  return sqrt((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy));
}


  // ----------------------------
  // IoU（マスクベース）
  // ----------------------------
  double _maskIoU(List<List<int>> mask1, List<List<int>> mask2) {
    final height = mask1.length;
    final width = mask1[0].length;
    int intersection = 0;
    int union = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask1[y][x] == 1 || mask2[y][x] == 1) {
          union++;
          if (mask1[y][x] == 1 && mask2[y][x] == 1) intersection++;
        }
      }
    }
    if (union == 0) return 0.0;
    return intersection / union;
  }
}
