import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'drawing_canvas.dart';
import 'drawing_controller.dart';
import 'route_generation_screen.dart';

class RouteDrawingScreen extends StatefulWidget {
  const RouteDrawingScreen({super.key, this.onDrawingReady});

  /// Optional observer of the snapshot passed to the preparation screen.
  final ValueChanged<DrawingData>? onDrawingReady;

  @override
  State<RouteDrawingScreen> createState() => _RouteDrawingScreenState();
}

class _RouteDrawingScreenState extends State<RouteDrawingScreen> {
  final DrawingController _drawing = DrawingController();
  double minDistanceKm = 4;
  double maxDistanceKm = 8;

  @override
  void dispose() {
    _drawing.dispose();
    super.dispose();
  }

  void _prepareDrawing() {
    final data = _drawing.snapshot();
    if (data == null) return;
    widget.onDrawingReady?.call(data);
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RouteGenerationScreen(drawing: data)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('루트 그리기')),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '달리고 싶은 그림을 그려보세요!',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: math.max(240, constraints.maxHeight - 420),
                child: DrawingCanvas(controller: _drawing),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('추천 모양', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SuggestedShape(label: '별', icon: Icons.star_outline_rounded),
                  _SuggestedShape(label: '하트', icon: Icons.favorite_border),
                  _SuggestedShape(label: '달', icon: Icons.dark_mode_outlined),
                  _SuggestedShape(label: '빈 추천 모양'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('거리 범위', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${minDistanceKm.toInt()}-${maxDistanceKm.toInt()}Km',
                    key: const Key('distance-range-label'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(minDistanceKm, maxDistanceKm),
                min: 1,
                max: 15,
                divisions: 14,
                labels: RangeLabels(
                  '${minDistanceKm.toInt()}km',
                  '${maxDistanceKm.toInt()}km',
                ),
                semanticFormatterCallback: (value) => '${value.toInt()} 킬로미터',
                onChanged: (values) => setState(() {
                  minDistanceKm = values.start.roundToDouble();
                  maxDistanceKm = values.end.roundToDouble();
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              ListenableBuilder(
                listenable: _drawing,
                builder: (context, _) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _drawing.hasDrawing ? _drawing.clear : null,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('초기화'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _drawing.hasDrawing ? _prepareDrawing : null,
                        icon: const Icon(Icons.search),
                        label: const Text('그림 찾기'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SuggestedShape extends StatelessWidget {
  const _SuggestedShape({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    onPressed: null,
    tooltip: label,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(56),
      shape: const CircleBorder(),
      side: const BorderSide(color: AppColors.border),
      disabledForegroundColor: AppColors.subText,
      backgroundColor: AppColors.surface,
    ),
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 28),
  );
}
