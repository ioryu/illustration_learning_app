import 'dart:math';
import 'package:flutter/foundation.dart';

/// ===============================
/// Isolate entry point
/// ===============================
double evaluateCoreIsolate(Map<String, dynamic> args) {
  final traced = args['traced'] as List<Map<String, double>>;
  final copied = args['copied'] as List<Map<String, double>>;
  final double dx = args['dx'];
  final double dy = args['dy'];
  final double scale = args['scale'];
  final int width = args['width'];
  final int height = args['height'];

  final tracedMask = _createMask(traced, width, height,
      scale: 1.0, offsetX: 0, offsetY: 0, lineWidth: 2);

  final copiedMask = _createMask(copied, width, height,
      scale: scale, offsetX: dx, offsetY: dy, lineWidth: 2);

  final dilatedTraced = _dilate(tracedMask, 10);
  final dilatedCopied = _dilate(copiedMask, 10);

  final iouScore = _maskIoU(dilatedTraced, dilatedCopied);

  final tracedSkel = _skeletonize(tracedMask);
  final copiedSkel = _skeletonize(copiedMask);

  final ssimScore = _maskSSIM(tracedSkel, copiedSkel);
  final shapeScore = _shapeScore(tracedMask, copiedMask);

  const wIou = 0.5;
  const wSsim = 0.6;
  const wShape = 0.5;

  double total = wIou * iouScore + wSsim * ssimScore + wShape * shapeScore;
  total = (total * 100).clamp(0.0, 100.0);

  return double.parse(total.toStringAsFixed(2));
}

/// ===============================
/// 以下は純Dart関数（UI依存なし）
/// ===============================

List<List<int>> _createMask(
  List<Map<String, double>> points,
  int width,
  int height, {
  double scale = 1.0,
  double offsetX = 0,
  double offsetY = 0,
  int lineWidth = 2,
}) {
  final mask =
      List.generate(height, (_) => List<int>.filled(width, 0));

  for (int i = 0; i < points.length - 1; i++) {
    final p1 = points[i];
    final p2 = points[i + 1];

    final x1 = (p1['x']! * scale + offsetX).round();
    final y1 = (p1['y']! * scale + offsetY).round();
    final x2 = (p2['x']! * scale + offsetX).round();
    final y2 = (p2['y']! * scale + offsetY).round();

    _drawLine(mask, x1, y1, x2, y2, lineWidth);
  }
  return mask;
}

void _drawLine(
  List<List<int>> mask,
  int x0,
  int y0,
  int x1,
  int y1,
  int lineWidth,
) {
  int dx = (x1 - x0).abs();
  int dy = (y1 - y0).abs();
  int sx = x0 < x1 ? 1 : -1;
  int sy = y0 < y1 ? 1 : -1;
  int err = dx - dy;

  while (true) {
    for (int lx = -lineWidth ~/ 2; lx <= lineWidth ~/ 2; lx++) {
      for (int ly = -lineWidth ~/ 2; ly <= lineWidth ~/ 2; ly++) {
        int nx = x0 + lx;
        int ny = y0 + ly;
        if (ny >= 0 &&
            ny < mask.length &&
            nx >= 0 &&
            nx < mask[0].length) {
          mask[ny][nx] = 1;
        }
      }
    }
    if (x0 == x1 && y0 == y1) break;
    int e2 = 2 * err;
    if (e2 > -dy) {
      err -= dy;
      x0 += sx;
    }
    if (e2 < dx) {
      err += dx;
      y0 += sy;
    }
  }
}

List<List<int>> _dilate(List<List<int>> mask, int r) {
  final h = mask.length;
  final w = mask[0].length;
  final out = List.generate(h, (_) => List<int>.filled(w, 0));

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (mask[y][x] == 1) {
        for (int dy = -r; dy <= r; dy++) {
          for (int dx = -r; dx <= r; dx++) {
            final ny = y + dy;
            final nx = x + dx;
            if (ny >= 0 && ny < h && nx >= 0 && nx < w) {
              out[ny][nx] = 1;
            }
          }
        }
      }
    }
  }
  return out;
}

List<List<int>> _skeletonize(List<List<int>> mask) {
  final h = mask.length;
  final w = mask[0].length;
  final skel = List.generate(h, (_) => List<int>.filled(w, 0));

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      if (mask[y][x] == 1) {
        skel[y][x] = 1;
      }
    }
  }
  return skel;
}

double _maskSSIM(List<List<int>> a, List<List<int>> b) {
  int match = 0, total = 0;
  for (int y = 0; y < a.length; y++) {
    for (int x = 0; x < a[0].length; x++) {
      if (a[y][x] == 1 || b[y][x] == 1) {
        total++;
        if (a[y][x] == b[y][x]) match++;
      }
    }
  }
  return total == 0 ? 0 : match / total;
}

double _shapeScore(List<List<int>> a, List<List<int>> b) {
  int overlap = 0, count = 0;
  for (int y = 0; y < a.length; y++) {
    for (int x = 0; x < a[0].length; x++) {
      if (a[y][x] == 1 || b[y][x] == 1) {
        count++;
        if (a[y][x] == 1 && b[y][x] == 1) overlap++;
      }
    }
  }
  return count == 0 ? 0 : overlap / count;
}

double _maskIoU(List<List<int>> a, List<List<int>> b) {
  int inter = 0, uni = 0;
  for (int y = 0; y < a.length; y++) {
    for (int x = 0; x < a[0].length; x++) {
      if (a[y][x] == 1 || b[y][x] == 1) {
        uni++;
        if (a[y][x] == 1 && b[y][x] == 1) inter++;
      }
    }
  }
  return uni == 0 ? 0 : inter / uni;
}
