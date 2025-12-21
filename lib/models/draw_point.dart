// import 'package:flutter/material.dart';

// class DrawPoint {
//   final Offset? offset;
//   final double strokeWidth;

//   DrawPoint(this.offset, {this.strokeWidth = 1.0});

//   Map<String, dynamic> toJson() {
//     return {
//       'offset': offset != null
//           ? {'dx': offset!.dx, 'dy': offset!.dy}
//           : null,
//       'strokeWidth': strokeWidth,
//     };
//   }

//   factory DrawPoint.fromJson(Map<String, dynamic> json) {
//     final offsetJson = json['offset'];
//     return DrawPoint(
//       offsetJson != null
//           ? Offset(offsetJson['dx'], offsetJson['dy'])
//           : null,
//       strokeWidth: json['strokeWidth'] ?? 4.0,
//     );
//   }
// }
import 'package:flutter/material.dart';

class DrawPoint {
  final Offset offset;
  final double strokeWidth;

  DrawPoint(
    this.offset, {
    this.strokeWidth = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'offset': {
        'dx': offset.dx,
        'dy': offset.dy,
      },
      'strokeWidth': strokeWidth,
    };
  }

  factory DrawPoint.fromJson(Map<String, dynamic> json) {
    final offsetJson = json['offset'];

    return DrawPoint(
      Offset(
        (offsetJson['dx'] as num).toDouble(),
        (offsetJson['dy'] as num).toDouble(),
      ),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
    );
  }
}
