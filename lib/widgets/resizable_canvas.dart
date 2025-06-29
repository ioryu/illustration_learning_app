import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/draw_point.dart';
import '../painters/drawing_painter.dart';

class ResizableCanvas extends StatefulWidget {
  final double imageWidth;
  final double imageHeight;
  final List<DrawPoint?> tracedPoints;
  final Offset? eraserPosition;
  final double eraserRadius;
  final Function(List<DrawPoint?>) onPointsChanged;
  final void Function(double width, double height)? onSizeChanged;
  final Color drawColor;
  final double strokeWidth;
  final bool isEraserMode;

  const ResizableCanvas({
    required this.imageWidth,
    required this.imageHeight,
    required this.tracedPoints,
    required this.onPointsChanged,
    this.eraserPosition,
    this.eraserRadius = 20.0,
    this.drawColor = Colors.red,
    this.strokeWidth = 4.0,
    required this.isEraserMode,
    this.onSizeChanged,
    super.key,
  });

  @override
  State<ResizableCanvas> createState() => _ResizableCanvasState();
}

// カスタムジェスチャー認識器
class DrawingGestureRecognizer extends OneSequenceGestureRecognizer {
  final Function(Offset) onDrawStart;
  final Function(Offset) onDrawUpdate;
  final Function() onDrawEnd;

  DrawingGestureRecognizer({
    required this.onDrawStart,
    required this.onDrawUpdate,
    required this.onDrawEnd,
  });

  @override
  String get debugDescription => 'drawing';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // 最初のポインターのみを受け入れる
    if (event.pointer == 0 || 
        event.kind == PointerDeviceKind.stylus ||
        (event.kind == PointerDeviceKind.touch && event.pressure > 0.7)) {
      startTrackingPointer(event.pointer, event.transform);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      resolve(GestureDisposition.accepted);
      onDrawStart(event.localPosition);
    } else if (event is PointerMoveEvent) {
      onDrawUpdate(event.localPosition);
    } else if (event is PointerUpEvent) {
      onDrawEnd();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // 何もしない
  }
}

class _ResizableCanvasState extends State<ResizableCanvas> {
  double top = 50;
  double left = 50;
  late double width;
  late double height;
  Offset? _eraserPosition;
  bool initialized = false;

  // 描画状態管理
  bool _isDrawing = false;
  int _activePointerCount = 0;
  final Map<int, PointerDeviceKind> _pointerTypes = {};
  
  @override
  void initState() {
    super.initState();
    width = widget.imageWidth;
    height = widget.imageHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        left = (screenWidth - width) / 2;
        top = -22;
      });
    });
  }

  void _erasePointsNear(Offset position) {
    for (int i = 0; i < widget.tracedPoints.length; i++) {
      final point = widget.tracedPoints[i];
      if (point == null || point.offset == null) continue;
      final distance = (point.offset! - position).distance;
      if (distance <= widget.eraserRadius) {
        widget.tracedPoints[i] = null;
      }
    }
  }

  void _handleDrawStart(Offset position) {
    if (_activePointerCount > 1) return; // マルチタッチ時は描画しない
    
    _isDrawing = true;
    _handleDrawing(position);
  }

  void _handleDrawUpdate(Offset position) {
    if (!_isDrawing || _activePointerCount > 1) return;
    
    _handleDrawing(position);
  }

  void _handleDrawEnd() {
    if (!_isDrawing) return;
    
    _isDrawing = false;
    if (!widget.isEraserMode) {
      setState(() {
        widget.tracedPoints.add(null);
        widget.onPointsChanged(List.from(widget.tracedPoints));
      });
    }
  }

  void _handleDrawing(Offset position) {
    setState(() {
      if (widget.isEraserMode) {
        _eraserPosition = position;
        _erasePointsNear(_eraserPosition!);
      } else {
        widget.tracedPoints.add(DrawPoint(position, strokeWidth: widget.strokeWidth));
      }
      widget.onPointsChanged(List.from(widget.tracedPoints));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!initialized) {
        left = (constraints.maxWidth - width) / 2;
        top = (constraints.maxHeight - height) / 2;
        initialized = true;
      }

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ポインター数を追跡するListener
                      Listener(
                        onPointerDown: (event) {
                          _activePointerCount++;
                          _pointerTypes[event.pointer] = event.kind;
                        },
                        onPointerUp: (event) {
                          _activePointerCount--;
                          _pointerTypes.remove(event.pointer);
                          if (_activePointerCount < 0) _activePointerCount = 0;
                        },
                        onPointerCancel: (event) {
                          _activePointerCount--;
                          _pointerTypes.remove(event.pointer);
                          if (_activePointerCount < 0) _activePointerCount = 0;
                        },
                        child: RawGestureDetector(
                          gestures: <Type, GestureRecognizerFactory>{
                            DrawingGestureRecognizer: GestureRecognizerFactoryWithHandlers<DrawingGestureRecognizer>(
                              () => DrawingGestureRecognizer(
                                onDrawStart: _handleDrawStart,
                                onDrawUpdate: _handleDrawUpdate,
                                onDrawEnd: _handleDrawEnd,
                              ),
                              (DrawingGestureRecognizer instance) {},
                            ),
                          },
                          child: Container(
                            width: width,
                            height: height,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: CustomPaint(
                              painter: DrawingPainter(
                                widget.tracedPoints,
                                originalCanvasSize: Size(width, height),
                                drawColor: widget.drawColor,
                                strokeWidth: widget.strokeWidth,
                                eraserPosition: widget.isEraserMode ? _eraserPosition : null,
                                eraserRadius: widget.eraserRadius,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 移動ハンドル
                      Positioned(
                        top: 0,
                        left: (width - 40) / 2,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            if (_isDrawing) return; // 描画中は移動無効
                            
                            setState(() {
                              top += details.delta.dy;
                              left += details.delta.dx;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4)
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.drag_handle,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),

                      // リサイズハンドル
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            if (_isDrawing) return; // 描画中はリサイズ無効
                            
                            setState(() {
                              width = (width + details.delta.dx).clamp(50.0, double.infinity);
                              height = (height + details.delta.dy).clamp(50.0, double.infinity);
                              widget.onSizeChanged?.call(width, height);
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.open_in_full,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}