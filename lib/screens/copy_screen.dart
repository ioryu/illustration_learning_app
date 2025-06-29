import 'package:flutter/material.dart';
import '../models/draw_point.dart';
import '../painters/drawing_painter.dart';
import 'overlay_check_screen.dart';

class CopyScreen extends StatefulWidget {
  final List<DrawPoint?> tracedPoints;
  final Size originalSize;
  final double currentStrokeWidth;

  const CopyScreen({
    Key? key,
    required this.tracedPoints,
    required this.originalSize,
    required this.currentStrokeWidth,
  }) : super(key: key);

  @override
  State<CopyScreen> createState() => _CopyScreenState();
}

class _CopyScreenState extends State<CopyScreen> {
  Size? userCanvasSize;
  List<List<DrawPoint?>> layers = [[]];
  List<double> layerOpacities = [1.0];
  int currentLayerIndex = 0;
  Offset _fabPosition = Offset.zero; // 初期位置（必要に応じて調整）


  bool isEraserMode = false;
  bool isSwapped = false;
  Offset? eraserPosition;
  final double eraserRadius = 20.0;
  double currentStrokeWidth = 4.0;

  List<DrawPoint?> get copiedPoints => layers[currentLayerIndex];

  @override
  void initState() {
    super.initState();
    currentStrokeWidth = widget.currentStrokeWidth;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        _fabPosition = Offset(
          screenSize.width - 120, // ボタン幅 + 余白
          screenSize.height - 250, // AppBar + BottomBar + 余白分
        );
        // print('初期FAB位置: $_fabPosition'); // ← ここで出力
      });
    });
  }


  void _handlePanUpdate(BuildContext context, DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);

    setState(() {
      if (isEraserMode) {
        eraserPosition = localPosition;
        for (int i = 0; i < copiedPoints.length; i++) {
          final p = copiedPoints[i];
          if (p != null && p.offset != null &&
              (p.offset! - localPosition).distance <= eraserRadius) {
            copiedPoints[i] = null;
          }
        }
      } else {
        eraserPosition = null;
        copiedPoints.add(DrawPoint(localPosition, strokeWidth: currentStrokeWidth));
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      if (!isEraserMode) copiedPoints.add(null);
      eraserPosition = null;
    });
  }

  void _navigateToOverlayCheck() {
    if (userCanvasSize == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OverlayCheckScreen(
          tracedPoints: widget.tracedPoints,
          copiedPoints: layers[currentLayerIndex],
          originalSize: userCanvasSize!,
        ),
      ),
    );
  }

  void _addNewLayer() {
    setState(() {
      layers.add([]);
      layerOpacities.add(1.0);
      currentLayerIndex = layers.length - 1;
    });
  }

  void _showStrokeWidthDialog() {
    double temp = currentStrokeWidth;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'ペンの太さ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blueAccent,
                  thumbColor: Colors.blueAccent,
                ),
                child: Slider(
                  min: 1,
                  max: 20,
                  divisions: 19,
                  value: temp,
                  label: '${temp.toStringAsFixed(1)} px',
                  onChanged: (v) => setStateDialog(() => temp = v),
                ),
              ),
              Text('${temp.toStringAsFixed(1)} px'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => currentStrokeWidth = temp);
              Navigator.pop(context);
            },
            child: const Text('決定'),
          ),
        ],
      ),
    );
  }

  void _showLayerSettingsDialog() {
    List<List<DrawPoint?>> tempLayers = List.from(layers.map((l) => List<DrawPoint?>.from(l)));
    List<double> tempOpacities = List.from(layerOpacities);
    int tempIndex = currentLayerIndex;
    double tempOpacity = tempOpacities[tempIndex];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFFFFFBF0),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('レイヤー設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('選択中レイヤー:'),
                        const SizedBox(width: 16),
                        DropdownButton<int>(
                          value: tempIndex,
                          items: List.generate(
                            tempLayers.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text('レイヤー ${index + 1}'),
                            ),
                          ),
                          onChanged: (index) {
                            if (index != null) {
                              setStateDialog(() {
                                tempIndex = index;
                                tempOpacity = tempOpacities[tempIndex];
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('透明度', style: TextStyle(fontSize: 16)),
                    Slider(
                      value: tempOpacity,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      label: '${(tempOpacity * 100).toInt()}%',
                      onChanged: (value) {
                        setStateDialog(() {
                          tempOpacity = value;
                          tempOpacities[tempIndex] = value;
                        });
                      },
                    ),
                    Center(child: Text('${(tempOpacity * 100).toInt()}%')),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('レイヤー追加'),
                        onPressed: () {
                          setStateDialog(() {
                            tempLayers.add([]);
                            tempOpacities.add(1.0);
                            tempIndex = tempLayers.length - 1;
                            tempOpacity = 1.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            layers = tempLayers;
                            layerOpacities = tempOpacities;
                            currentLayerIndex = tempIndex;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }


  Widget _buildUserCanvas() {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          userCanvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanUpdate: (details) => _handlePanUpdate(context, details),
            onPanEnd: _handlePanEnd,
            child: CustomPaint(
              painter: _CombinedPainter(
                layers: layers,
                opacities: layerOpacities,
                currentLayerIndex: currentLayerIndex,
                eraserPosition: isEraserMode ? eraserPosition : null,
                eraserRadius: eraserRadius,
                strokeWidth: currentStrokeWidth,
              ),
              size: userCanvasSize!,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTracedCanvas() {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            painter: DrawingPainter(
              widget.tracedPoints,
              drawColor: Colors.red,
              originalCanvasSize: widget.originalSize,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          );
        },
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 2,
      color: Colors.grey.shade400,
    );
  }

  Widget _buildLabeledCanvas(String label, Widget canvas) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            color: Colors.blue.shade50,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: canvas),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('模写画面'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFBF0),
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '左右を入れ替え',
            onPressed: () => setState(() => isSwapped = !isSwapped),
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: isSwapped
                ? [
                    _buildLabeledCanvas('模写', _buildUserCanvas()),
                    _buildDivider(),
                    _buildLabeledCanvas('トレス線', _buildTracedCanvas()),
                  ]
                : [
                    _buildLabeledCanvas('トレス線', _buildTracedCanvas()),
                    _buildDivider(),
                    _buildLabeledCanvas('模写', _buildUserCanvas()),
                  ],
          ),
          // ドラッグ可能な「次へ」ボタン
          if (layers.any((l) => l.any((p) => p != null)))
            Positioned(
              left: _fabPosition.dx,
              top: _fabPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _fabPosition += details.delta;
                  });
                },
                child: FloatingActionButton.extended(
                  onPressed: _navigateToOverlayCheck,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('次へ'),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFFFFBF0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  isEraserMode ? Icons.cleaning_services : Icons.brush,
                  color: isEraserMode ? Colors.grey : Colors.blueAccent,
                ),
                tooltip: isEraserMode ? '消しゴムモード' : 'ペンモード',
                onPressed: () => setState(() => isEraserMode = !isEraserMode),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'ペンの太さ',
                onPressed: _showStrokeWidthDialog,
              ),
              IconButton(
                icon: const Icon(Icons.layers),
                tooltip: 'レイヤー設定',
                onPressed: _showLayerSettingsDialog,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'レイヤーを全消去',
                onPressed: () => setState(() => layers[currentLayerIndex].clear()),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _CombinedPainter extends CustomPainter {
  final List<List<DrawPoint?>> layers;
  final List<double> opacities;
  final int currentLayerIndex;
  final Offset? eraserPosition;
  final double eraserRadius;
  final double strokeWidth;

  _CombinedPainter({
    required this.layers,
    required this.opacities,
    required this.currentLayerIndex,
    this.eraserPosition,
    required this.eraserRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final isCurrent = (i == currentLayerIndex);
      final painter = DrawingPainter(
        layer,
        drawColor: Colors.black.withOpacity(opacities[i]),
        eraserPosition: isCurrent ? eraserPosition : null,
        eraserRadius: eraserRadius,
        strokeWidth: strokeWidth,
      );
      painter.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _CombinedPainter oldDelegate) => true;
}
