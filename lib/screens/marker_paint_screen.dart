import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';

import 'copy_screen.dart'; // CopyScreen のパスに合わせてください
import '../models/draw_point.dart';

class MarkerPaintScreen extends StatefulWidget {
  const MarkerPaintScreen({super.key});

  @override
  State<MarkerPaintScreen> createState() => _MarkerPaintScreenState();
}

class _MarkerPaintScreenState extends State<MarkerPaintScreen> {
  File? selectedFile;
  Size? _drawingAreaSize;
  Rect? _cropRect;

  double _threshold = 1.0; // スライダー値
  img.Image? _originalImage;
  img.Image? _originalLineImage; // 線画保存
  img.Image? _processedImage;
  Uint8List? _displayedBytes;

  /// 画像選択
  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      _originalImage = img.decodeImage(bytes)!;

      // 線画を作成
      _createLineImage();

      setState(() {
        selectedFile = File(pickedFile.path);
        _drawingAreaSize = null;
      });
    }
  }

  /// 線画を作成（画像選択時のみ）
  void _createLineImage() {
    if (_originalImage == null) return;

    final tempImage = img.Image.from(_originalImage!);
    final gray = img.grayscale(tempImage);
    final edges = img.sobel(gray);
    _originalLineImage = img.invert(edges);

    _processedImage = img.Image.from(_originalLineImage!);
    _displayedBytes = Uint8List.fromList(img.encodeJpg(_processedImage!));
  }

  /// スライダーで閾値処理
void _applyThreshold() {
  if (_originalLineImage == null) return;

  // 元画像をコピー
  _processedImage = img.Image.from(_originalLineImage!);
  final width = _processedImage!.width;
  final height = _processedImage!.height;

  final thresholdValue = (_threshold * 25).toInt();

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = _processedImage!.getPixel(x, y);

      if (pixel.r < thresholdValue) {
        _processedImage!.setPixelRgba(x, y, 255, 255, 255, 255);
      }
      // else はそのまま
    }
  }

  _displayedBytes = Uint8List.fromList(img.encodeJpg(_processedImage!));
}









  /// 表示サイズ計算
  Future<void> _calculateDrawingAreaSize(BoxConstraints constraints) async {
    if (_displayedBytes == null) return;
    final decodedImage = await decodeImageFromList(_displayedBytes!);
    final displaySize = calculateImageSize(
      maxWidth: constraints.maxWidth,
      maxHeight: constraints.maxHeight,
      imageWidth: decodedImage.width.toDouble(),
      imageHeight: decodedImage.height.toDouble(),
    );
    if (_drawingAreaSize != displaySize) {
      setState(() => _drawingAreaSize = displaySize);
    }
  }

  /// トリミング処理
  Future<Uint8List> cropImage() async {
    if (_processedImage == null || _cropRect == null || _drawingAreaSize == null) {
      throw Exception("画像またはトリミング範囲が未設定です");
    }

    final scaleX = _processedImage!.width / _drawingAreaSize!.width;
    final scaleY = _processedImage!.height / _drawingAreaSize!.height;

    final crop = img.copyCrop(
      _processedImage!,
      x: (_cropRect!.left * scaleX).round(),
      y: (_cropRect!.top * scaleY).round(),
      width: (_cropRect!.width * scaleX).round(),
      height: (_cropRect!.height * scaleY).round(),
    );

    return Uint8List.fromList(img.encodeJpg(crop));
  }

  void _goToNextScreen() async {
  try {
    final croppedBytes = await cropImage();
    if (!mounted) return;

    final img.Image decoded = img.decodeImage(croppedBytes)!;

    final List<DrawPoint?> tracedPoints = [];
    for (int y = 0; y < decoded.height; y++) {
      for (int x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y); // Pixel 型

        // Pixel クラスの r, g, b を使う
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        final brightness = (r + g + b) / 3;

        if (brightness < 200) {
          tracedPoints.add(DrawPoint(Offset(x.toDouble(), y.toDouble()), strokeWidth: 1));
        } else {
          tracedPoints.add(null);
        }
      }
      tracedPoints.add(null); // 横ラインごとに null
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CopyScreen(
          tracedPoints: tracedPoints,
          originalSize: Size(decoded.width.toDouble(), decoded.height.toDouble()),
          currentStrokeWidth: 1.0,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("トリミング画像変換に失敗しました: $e")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
      appBar: AppBar(
        title: const Text('トリミング'),
        backgroundColor: const Color(0xFFFFFBF0),
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: '画像を選択',
            onPressed: pickImage,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: _displayedBytes == null
                ? Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('画像を選択'),
                      onPressed: pickImage,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (_drawingAreaSize == null) {
                        _calculateDrawingAreaSize(constraints);
                        return const Center(child: CircularProgressIndicator());
                      }

                      final imageWidth = _drawingAreaSize!.width;
                      final imageHeight = _drawingAreaSize!.height;
                      final imageLeft = (constraints.maxWidth - imageWidth) / 2;
                      final imageTop = (constraints.maxHeight - imageHeight) / 2;

                      return Stack(
                        children: [
                          Positioned(
                            left: imageLeft,
                            top: imageTop,
                            width: imageWidth,
                            height: imageHeight,
                            child: Image.memory(_displayedBytes!, fit: BoxFit.contain),
                          ),
                          Positioned(
                            left: imageLeft,
                            top: imageTop,
                            width: imageWidth,
                            height: imageHeight,
                            child: CropRect(
                              imageWidth: imageWidth,
                              imageHeight: imageHeight,
                              onChanged: (rect) {
                                setState(() => _cropRect = rect);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFFFFBF0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: 10,
                  divisions: 20,
                  value: _threshold,
                  onChanged: (value) {
                    setState(() {
                      _threshold = value;
                      _applyThreshold(); // 線画をベースに閾値処理
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _goToNextScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("次へ"),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}




/// トリミング枠（変更なし）
class CropRect extends StatefulWidget {
  final double imageWidth;
  final double imageHeight;
  final void Function(Rect rect)? onChanged;

  const CropRect({
    required this.imageWidth,
    required this.imageHeight,
    this.onChanged,
    super.key,
  });

  @override
  State<CropRect> createState() => _CropRectState();
}

class _CropRectState extends State<CropRect> {
  late Rect cropRect;
  final double handleSize = 25;

  @override
void initState() {
super.initState();
cropRect = Rect.fromLTWH(0, 0, widget.imageWidth, widget.imageHeight);
// 初期値を親に通知
WidgetsBinding.instance.addPostFrameCallback((_) {
    widget.onChanged?.call(cropRect);
});
}


  void _onDrag(DragUpdateDetails details, String corner) {
    setState(() {
      double left = cropRect.left;
      double top = cropRect.top;
      double right = cropRect.right;
      double bottom = cropRect.bottom;

      switch (corner) {
        case 'tl':
          left += details.delta.dx;
          top += details.delta.dy;
          break;
        case 'tr':
          right += details.delta.dx;
          top += details.delta.dy;
          break;
        case 'bl':
          left += details.delta.dx;
          bottom += details.delta.dy;
          break;
        case 'br':
          right += details.delta.dx;
          bottom += details.delta.dy;
          break;
      }

      left = left.clamp(0.0, widget.imageWidth - 10);
      right = right.clamp(left + 10, widget.imageWidth);
      top = top.clamp(0.0, widget.imageHeight - 10);
      bottom = bottom.clamp(top + 10, widget.imageHeight);

      cropRect = Rect.fromLTRB(left, top, right, bottom);
      widget.onChanged?.call(cropRect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fromRect(
          rect: cropRect,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
            ),
          ),
        ),
        ...['tl', 'tr', 'bl', 'br'].map((corner) {
          double x = (corner.contains('l') ? cropRect.left : cropRect.right) - handleSize / 2;
          double y = (corner.contains('t') ? cropRect.top : cropRect.bottom) - handleSize / 2;
          return Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onPanUpdate: (details) => _onDrag(details, corner),
              child: Container(
                width: handleSize,
                height: handleSize,
                color: Colors.red,
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// 次の画面：トリミング結果を表示
class NextScreen extends StatelessWidget {
  final Uint8List croppedImageBytes;

  const NextScreen({super.key, required this.croppedImageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("トリミング結果")),
      body: Center(
        child: Image.memory(croppedImageBytes),
      ),
    );
  }
}
