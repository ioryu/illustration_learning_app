import 'package:flutter/material.dart';
import '../models/draw_point.dart';
import '../painters/trace_only_painter.dart';
import '../painters/copy_with_frame_painter.dart';
import 'home_screen.dart';

class EvaluationScreen extends StatefulWidget {
  final List<DrawPoint?> tracedPoints;
  final List<DrawPoint?> copiedPoints;
  final Size originalSize;
  final Offset adjustedPosition;
  final double adjustedScale;
  final Map<String, dynamic> evaluationResult;

  const EvaluationScreen({
    Key? key,
    required this.tracedPoints,
    required this.copiedPoints,
    required this.originalSize,
    required this.adjustedPosition,
    required this.adjustedScale,
    required this.evaluationResult,
  }) : super(key: key);

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  String getMessageForScore(double score) {
    if (score >= 90) return "完璧！すばらしい出来です！";
    if (score >= 75) return "よくできました！あと少しで完璧！";
    if (score >= 60) return "なかなかいい感じです！";
    return "もう少し頑張って！";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('評価結果'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFBF0),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          final overlayLeft = (canvasSize.width - widget.originalSize.width) / 2 + widget.adjustedPosition.dx;
          final overlayTop = (canvasSize.height - widget.originalSize.height) / 2 + widget.adjustedPosition.dy;

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
                left: overlayLeft,
                top: overlayTop,
                child: Transform.scale(
                  scale: widget.adjustedScale,
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      size: widget.originalSize,
                      painter: CopyWithFramePainter(
                        copiedPoints: widget.copiedPoints,
                        canvasSize: widget.originalSize,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'スコア: ${widget.evaluationResult['score'].toStringAsFixed(2)} 点',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        getMessageForScore(widget.evaluationResult['score']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFFFFFBF0),
              title: const Text("ホームに戻りますか？"),
              content: const Text("一度ホームに戻るとこの画面には戻れません。よろしいですか？"),
              actions: [
                TextButton(
                  child: const Text("キャンセル"),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text("戻る"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.home),
        label: const Text("ホームに戻る"),
      ),
    );
  }
}
