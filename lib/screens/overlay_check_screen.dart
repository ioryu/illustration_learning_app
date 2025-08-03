import 'package:flutter/material.dart';
import '../models/draw_point.dart';
import '../painters/trace_only_painter.dart';
import '../painters/copy_with_frame_painter.dart';
import 'evaluation_screen.dart';
import '../utils/user_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/navigation_with_ad.dart';

class OverlayCheckScreen extends StatefulWidget {
  final List<DrawPoint?> tracedPoints;
  final List<DrawPoint?> copiedPoints;
  final Size originalSize;

  const OverlayCheckScreen({
    Key? key,
    required this.tracedPoints,
    required this.copiedPoints,
    required this.originalSize,
  }) : super(key: key);

  @override
  State<OverlayCheckScreen> createState() => _OverlayCheckScreenState();
}

class _OverlayCheckScreenState extends State<OverlayCheckScreen> {
  Offset copiedImagePosition = Offset.zero;
  double copiedImageScale = 1.0;
  bool isDraggingHandle = false;
  final double handleSize = 24.0;
  final double minScale = 0.5;
  final double maxScale = 3.0;
  bool _isInitialized = false;
  Size? _currentCanvasSize;
  Map<String, dynamic>? _evaluationResult;

  Future<bool> _sendEvaluationRequest() async {
    String uuid = await getOrCreateUUID();
    if (_currentCanvasSize == null) return false;

    final normalizedDx = copiedImagePosition.dx - (_currentCanvasSize!.width - widget.originalSize.width) / 2;
    final normalizedDy = copiedImagePosition.dy - (_currentCanvasSize!.height - widget.originalSize.height) / 2;

    final tracedJson = widget.tracedPoints.map((p) => p?.toJson()).toList();
    final copiedJson = widget.copiedPoints.map((p) => p?.toJson()).toList();

    final Map<String, dynamic> data = {
      'uuid': uuid,
      'tracedPoints': tracedJson,
      'copiedPoints': copiedJson,
      'originalSize': {
        'width': widget.originalSize.width,
        'height': widget.originalSize.height,
      },
      'adjustedPosition': {'dx': normalizedDx, 'dy': normalizedDy},
      'adjustedScale': copiedImageScale,
    };

    try {
      final response = await http.post(
        Uri.parse('https://illustrationevaluation.onrender.com/evaluate'),
        // Uri.parse('http://127.0.0.1:5000/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        _evaluationResult = json.decode(response.body);
        return true;
      }
    } catch (e) {
      print('通信エラー: $e');
    }

    _showEvaluationErrorDialog();
    return false;
  }

  void _showEvaluationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF0),
        title: const Text('評価失敗'),
        content: const Text('サーバーでエラーが発生しました。時間をおいて再度お試しください。'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _navigateToEvaluation() {
    navigateWithAdEvery3rdTime(
      context: context,
      destinationBuilder: () async {
        final success = await _sendEvaluationRequest();
        if (!success || _evaluationResult == null) {
          throw Exception("評価失敗のため画面遷移を中止");
        }

        final normalizedDx = copiedImagePosition.dx - (_currentCanvasSize!.width - widget.originalSize.width) / 2;
        final normalizedDy = copiedImagePosition.dy - (_currentCanvasSize!.height - widget.originalSize.height) / 2;

        return EvaluationScreen(
          tracedPoints: widget.tracedPoints,
          copiedPoints: widget.copiedPoints,
          originalSize: widget.originalSize,
          adjustedPosition: Offset(normalizedDx, normalizedDy),
          adjustedScale: copiedImageScale,
          evaluationResult: _evaluationResult!,
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('重ねて確認'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFBF0),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          _currentCanvasSize = canvasSize;

          if (!_isInitialized) {
            final imageWidth = widget.originalSize.width * copiedImageScale;
            final imageHeight = widget.originalSize.height * copiedImageScale;
            copiedImagePosition = Offset(
              (canvasSize.width - imageWidth) / 2,
              (canvasSize.height - imageHeight) / 2,
            );
            _isInitialized = true;
          }

          return Stack(
            children: [
              CustomPaint(
                size: canvasSize,
                painter: TraceOnlyPainter(
                  tracedPoints: widget.tracedPoints,
                  originalCanvasSize: widget.originalSize,
                ),
              ),
              Positioned(
                left: copiedImagePosition.dx,
                top: copiedImagePosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (!isDraggingHandle) {
                      setState(() => copiedImagePosition += details.delta);
                    }
                  },
                  child: Transform.scale(
                    scale: copiedImageScale,
                    alignment: Alignment.topLeft,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: widget.originalSize,
                          painter: CopyWithFramePainter(
                            copiedPoints: widget.copiedPoints,
                            canvasSize: widget.originalSize,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onPanStart: (_) => setState(() => isDraggingHandle = true),
                            onPanUpdate: (details) {
                              setState(() {
                                double delta = details.delta.dx * 0.002;
                                copiedImageScale += delta * copiedImageScale;
                                copiedImageScale = copiedImageScale.clamp(minScale, maxScale);
                              });
                            },
                            onPanEnd: (_) => setState(() => isDraggingHandle = false),
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                            ),

                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '操作ヒント：コピー画像を移動・右下の四角で拡大縮小できます',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text(
              '※3回に1回程度\n広告が流れることがあります',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          FloatingActionButton.extended(
            onPressed: _navigateToEvaluation,
            icon: const Icon(Icons.assessment),
            label: const Text('評価する'),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        ],
      ),


    );
  }
}
