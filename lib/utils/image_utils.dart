import 'package:flutter/material.dart';

import '../models/draw_point.dart';

Size calculateImageSize({
  required double maxWidth,
  required double maxHeight,
  required double imageWidth,
  required double imageHeight,
}) {
  final imageRatio = imageWidth / imageHeight;
  final containerRatio = maxWidth / maxHeight;

  double displayWidth;
  double displayHeight;

  if (imageRatio > containerRatio) {
    displayWidth = maxWidth;
    displayHeight = maxWidth / imageRatio;
  } else {
    displayHeight = maxHeight;
    displayWidth = maxHeight * imageRatio;
  }

  return Size(displayWidth, displayHeight);
}



// Map<String, dynamic> buildEvaluationRequestBody({
//   required List<DrawPoint?> tracedPoints,
//   required List<DrawPoint?> copiedPoints,
//   required Offset adjustedPosition,
//   required double adjustedScale,
// }) {
//   return {
//     'traced_points': tracedPoints.map((p) => p?.toJson()).toList(),
//     'copied_points': copiedPoints.map((p) => p?.toJson()).toList(),
//     'adjusted_position': {
//       'dx': adjustedPosition.dx,
//       'dy': adjustedPosition.dy,
//     },
//     'adjusted_scale': adjustedScale,
//   };
// }
