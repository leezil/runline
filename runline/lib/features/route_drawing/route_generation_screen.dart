import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'drawing_controller.dart';

class RouteGenerationScreen extends StatelessWidget {
  const RouteGenerationScreen({super.key, required this.drawing});

  final DrawingData drawing;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('경로 만들기')),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: DrawingPreview(drawing: drawing)),
            const SizedBox(height: AppSpacing.md),
            const Text('그린 모양을 바탕으로 러닝 경로를 생성할 준비가 되었습니다.'),
            const SizedBox(height: AppSpacing.xs),
            Text('전체 point 개수: ${drawing.points.length}개'),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '경로 생성 API 연결 후 사용할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const FilledButton(onPressed: null, child: Text('경로 생성')),
          ],
        ),
      ),
    ),
  );
}

/// Fits the saved canvas without changing its aspect ratio or stroke data.
class DrawingPreview extends StatelessWidget {
  const DrawingPreview({super.key, required this.drawing});

  final DrawingData drawing;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '그린 모양 미리보기',
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: drawing.canvasSize.isEmpty || !drawing.canvasSize.isFinite
          ? const SizedBox.shrink()
          : FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: drawing.canvasSize,
                  painter: _DrawingPreviewPainter(drawing),
                ),
              ),
            ),
    ),
  );
}

class _DrawingPreviewPainter extends CustomPainter {
  const _DrawingPreviewPainter(this.drawing);

  final DrawingData drawing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(Colors.white, BlendMode.src);
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in drawing.strokes) {
      if (stroke.isEmpty) continue;
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
  }

  @override
  bool shouldRepaint(covariant _DrawingPreviewPainter oldDelegate) =>
      oldDelegate.drawing != drawing;
}
