import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import 'drawing_controller.dart';

class DrawingCanvas extends StatelessWidget {
  const DrawingCanvas({super.key, required this.controller});

  final DrawingController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '루트 그리기 캔버스',
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          controller.updateViewport(viewport);
          return GestureDetector(
            key: const Key('drawing-canvas-input'),
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) =>
                controller.beginStroke(details.localPosition, viewport),
            onPanUpdate: (details) =>
                controller.addPoint(details.localPosition, viewport),
            onPanEnd: (_) => controller.endStroke(),
            onPanCancel: controller.endStroke,
            child: RepaintBoundary(
              child: CustomPaint(
                foregroundPainter: _DrawingPainter(controller),
                child: const ColoredBox(
                  color: Colors.white,
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
