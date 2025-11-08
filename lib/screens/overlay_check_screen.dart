import 'package:flutter/material.dart';
import '../models/draw_point.dart';
import '../painters/trace_only_painter.dart';
import '../painters/copy_with_frame_painter.dart';
import 'evaluation_screen.dart';
import '../utils/user_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/navigation_with_ad.dart';
import 'dart:async';  
import '../services/server_service.dart';
import 'home_screen.dart';



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
  final double minScale = 0.1;
  final double maxScale = 3.0;
  bool _isInitialized = false;
  Size? _currentCanvasSize;
  Map<String, dynamic>? _evaluationResult;

  @override
  void initState() {
    super.initState();

    // 画面描画後にサーバ通信
    // サーバのウォームアップ（非同期で投げっぱなし）
    ServerService.isServerCold().then((cold) {
      print('起動時のサーバ応答: ${cold ? "スリープ状態" : "起動済み"}');
    }).catchError((e) {
      print('起動時ping失敗: $e');
    });
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _sendEvaluationRequest().then((success) {
    //     if (success) {
    //       print("サーバ通信成功");
    //     } else {
    //       print("サーバ通信失敗");
    //     }
    //   });
    // });
  }

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
    bool serverReady = false;

    // try {
    //   serverReady = !(await ServerService.isServerCold(timeoutSeconds: 10));
    //   print('サーバ応答: ${serverReady ? "起動済み" : "スリープ状態"}');
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text("サーバping失敗: $e")),
    //     );
    //   print('サーバping失敗: $e');
    //   serverReady = false;
    // }
  serverReady = true; // とりあえず常に送信する
    if (!serverReady) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("サーバが起動していないため送信しません")),
        );
      print("サーバが起動していないため送信しません");
      return false; // ここで処理を中断
    }

    try {
      // タイムアウトを10秒に設定
      final response = await http
          .post(
            Uri.parse("https://illustrationevaluation.onrender.com/evaluate"), // 実際のサーバURLに置き換える
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _evaluationResult = jsonDecode(response.body);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("サーバエラー: ${response.statusCode}")),
        );
        print("サーバエラー: ${response.statusCode}");
        return false;
      }
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("サーバ応答がタイムアウトしました")),
        );
      print("サーバ応答がタイムアウトしました");
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("サーバ通信中にエラー発生: $e")),
        );
      print("サーバ通信中にエラー発生: $e");
      return false;
    }
  }


  bool _isSending = false;

  void _navigateToEvaluation() async {
    if (_isSending) 
    
    return; // 送信中は無視
    _isSending = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _sendEvaluationRequest();

      Navigator.of(context).pop(); // ローディング閉じる

      if (!success || _evaluationResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("評価に失敗しました。3分くらいして再度お試しください。")),
        );
        _isSending = false;
        return;
      }

      final normalizedDx = copiedImagePosition.dx - (_currentCanvasSize!.width - widget.originalSize.width) / 2;
      final normalizedDy = copiedImagePosition.dy - (_currentCanvasSize!.height - widget.originalSize.height) / 2;

      await navigateWithAdEvery3rdTime(
        context: context,
        destinationBuilder: () async {
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

    } catch (e) {
      Navigator.of(context).pop(); // ローディング閉じる
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("エラーが発生しました: $e")),
      );
    } finally {
      _isSending = false; // 最後に必ずフラグ解除
    }
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
              '※広告が流れることがあります',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          // 評価ボタン
          FloatingActionButton.extended(
            onPressed: _navigateToEvaluation,
            icon: const Icon(Icons.assessment),
            label: const Text('評価する'),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          // ホームに戻るボタン
          FloatingActionButton.extended(
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
                        Navigator.of(context).pop(); // ダイアログを閉じる
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
            backgroundColor: Colors.orangeAccent,
            foregroundColor: Colors.white,
          ),
        ],
      ),



    );
  }
}
