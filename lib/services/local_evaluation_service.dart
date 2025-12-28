import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/draw_point.dart';
import '../repositories/local_history_repository.dart';
import '../services/evaluation_isolate.dart';

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

    // null除外
    final traced = tracedPoints.whereType<DrawPoint>().toList();
    final copied = copiedPoints.whereType<DrawPoint>().toList();

    // Isolate に渡せる形へ変換
    final tracedData = traced
        .map((p) => {
              'x': p.offset.dx,
              'y': p.offset.dy,
            })
        .toList();

    final copiedData = copied
        .map((p) => {
              'x': p.offset.dx,
              'y': p.offset.dy,
            })
        .toList();

    // ----------------------------
    // ★ Isolate で重い評価処理を実行
    // ----------------------------
    final double totalScore = await compute(
      evaluateCoreIsolate,
      {
        'traced': tracedData,
        'copied': copiedData,
        'dx': adjustedPosition.dx,
        'dy': adjustedPosition.dy,
        'scale': adjustedScale,
        'width': originalSize.width.toInt(),
        'height': originalSize.height.toInt(),
      },
    );

    // ----------------------------
    // 履歴保存
    // ----------------------------
    await historyRepository.saveEvaluationResult(
      uuid: uuid,
      totalScore: totalScore,
    );

    debugPrint('保存するデータ: uuid=$uuid, totalScore=$totalScore');

    return {
      'message': '評価完了',
      'score': totalScore,
    };
  }
}
