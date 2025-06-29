import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/draw_point.dart';
import '../widgets/resizable_canvas.dart';
import '../utils/image_utils.dart';
import 'copy_screen.dart';

class EdgeDetectionScreen extends StatefulWidget {
  const EdgeDetectionScreen({super.key});

  @override
  State<EdgeDetectionScreen> createState() => _EdgeDetectionScreenState();
}

class _EdgeDetectionScreenState extends State<EdgeDetectionScreen> {
  final GlobalKey _imageKey = GlobalKey();
  Offset canvasOffset = const Offset(0, 0);
  Size? _drawingAreaSize;
  Size? newAreaSize;
  double currentStrokeWidth = 4.0;
  bool isEraserMode = false;
  Offset? eraserPosition;
  final double eraserRadius = 20.0;
  List<DrawPoint?> points = [];
  File? edgeImage;
  bool _isPickingImage = false;

  Future<void> pickAndProcessImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        await detectEdges(imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> detectEdges(File imageFile) async {
    setState(() {
      edgeImage = imageFile;
      _drawingAreaSize = null;
      newAreaSize = null;
      points.clear();
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      points.add(null);
    });
  }

  void _handlePanUpdate(BuildContext innerContext, DragUpdateDetails details) {
    final box = innerContext.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      if (isEraserMode) {
        eraserPosition = local;
      } else {
        eraserPosition = null;
        points.add(DrawPoint(local, strokeWidth: currentStrokeWidth));
      }
    });
  }

  Future<void> _calculateAndSetDrawingAreaSize(BoxConstraints constraints) async {
    if (edgeImage == null) return;
    final decodedImage = await decodeImageFromList(File(edgeImage!.path).readAsBytesSync());
    final imageWidth = decodedImage.width.toDouble();
    final imageHeight = decodedImage.height.toDouble();

    final displaySize = calculateImageSize(
      maxWidth: constraints.maxWidth,
      maxHeight: constraints.maxHeight,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    if (_drawingAreaSize != displaySize) {
      setState(() {
        _drawingAreaSize = displaySize;
        newAreaSize = displaySize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('線画抽出とトレス'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFBF0),
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: '画像を選択',
            onPressed: pickAndProcessImage,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: edgeImage == null
                ? Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('画像を選択'),
                      onPressed: pickAndProcessImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (_drawingAreaSize == null) {
                        _calculateAndSetDrawingAreaSize(constraints);
                        return const Center(child: CircularProgressIndicator());
                      }

                      final imageWidth = _drawingAreaSize!.width;
                      final imageHeight = _drawingAreaSize!.height;

                      return InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center, // ← これを追加！
                            children: [
                              SizedBox(
                                width: imageWidth,
                                height: imageHeight,
                                child: Image.file(
                                  File(edgeImage!.path),
                                  key: _imageKey,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              ResizableCanvas(
                                imageWidth: imageWidth,
                                imageHeight: imageHeight,
                                tracedPoints: points,
                                strokeWidth: currentStrokeWidth,
                                onPointsChanged: (updatedPoints) {
                                  setState(() => points = updatedPoints);
                                },
                                eraserPosition: eraserPosition,
                                eraserRadius: eraserRadius,
                                isEraserMode: isEraserMode,
                                onSizeChanged: (w, h) {
                                  setState(() => newAreaSize = Size(w, h));
                                },
                              ),
                            ],
                          ),
                        ),

                      );


                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '操作ヒント：ピンチで拡大、バーでキャンバス移動、ボタンで描画・消去切替',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFFFFBF0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
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
                icon: const Icon(Icons.delete),
                tooltip: '全て消去',
                onPressed: () => setState(() => points.clear()),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'ペンの太さ設定',
                onPressed: () {
                  double temp = currentStrokeWidth;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFFFFFBF0),
                      title: const Text('ペンの太さ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                                min: 1.0,
                                max: 20.0,
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
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: edgeImage != null && points.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CopyScreen(
                      tracedPoints: points,
                      originalSize: newAreaSize!,
                      currentStrokeWidth: currentStrokeWidth,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('模写へ進む'),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
