import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import 'drawing_controller.dart';

class DrawingCanvas extends StatelessWidget {
  const DrawingCanvas({super.key, required this.controller});

  static const paperColor = Color(0xFFF0F4FE);

  final DrawingController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '루트 그리기 캔버스',
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          controller.updateViewport(viewport);
          return RawGestureDetector(
            key: const Key('drawing-canvas-input'),
            behavior: HitTestBehavior.opaque,
            gestures: {
              _DrawingGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _DrawingGestureRecognizer
                  >(_DrawingGestureRecognizer.new, (recognizer) {
                    recognizer.dragStartBehavior = DragStartBehavior.down;
                    recognizer.onDown = (details) =>
                        controller.beginStroke(details.localPosition, viewport);
                    recognizer.onUpdate = (details) =>
                        controller.addPoint(details.localPosition, viewport);
                    recognizer.onEnd = (_) => controller.endStroke();
                    recognizer.onCancel = controller.endStroke;
                  }),
            },
            child: RepaintBoundary(
              child: CustomPaint(
                foregroundPainter: _DrawingPainter(controller),
                child: const ColoredBox(
                  color: paperColor,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _DrawingGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Claim strokes before the enclosing scroll view can accept vertical drags.
    resolve(GestureDisposition.accepted);
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.controller)
    : _coordinateSize = controller.canvasSize,
      super(repaint: controller);

  final DrawingController controller;
  final Size _coordinateSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.hasDrawing) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / controller.canvasSize.width,
      size.height / controller.canvasSize.height,
    );
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in controller.strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          paint.strokeWidth / 2,
          Paint()..color = AppColors.primary,
        );
      } else {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (final point in stroke.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate._coordinateSize != _coordinateSize;
}
