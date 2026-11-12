import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'drawing_canvas.dart';
import 'drawing_controller.dart';
import 'drawing_presets.dart';
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
      MaterialPageRoute(
        builder: (_) => RouteGenerationScreen(
          drawing: data,
          minDistanceKm: minDistanceKm,
          maxDistanceKm: maxDistanceKm,
        ),
      ),
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
              ListenableBuilder(
                listenable: _drawing,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final preset in DrawingPreset.values)
                      _SuggestedShape(
                        preset: preset,
                        selected: _drawing.selectedPreset == preset,
                        onPressed: () => _drawing.selectPreset(preset),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '모양을 선택하거나 직접 그려보세요. 실제 도로에 따라 생성되는 경로의 모양은 달라질 수 있습니다.',
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
  const _SuggestedShape({
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  final DrawingPreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        selected: selected,
        child: IconButton.outlined(
          key: ValueKey('preset-${preset.name}'),
          onPressed: onPressed,
          isSelected: selected,
          tooltip: preset.label,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(56),
            shape: const CircleBorder(),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            foregroundColor: selected ? AppColors.primary : AppColors.subText,
            backgroundColor: selected
                ? AppColors.primary.withValues(alpha: .1)
                : AppColors.surface,
          ),
          icon: Icon(switch (preset) {
            DrawingPreset.star => Icons.star_outline_rounded,
            DrawingPreset.heart => Icons.favorite_border,
            DrawingPreset.crescent => Icons.dark_mode_outlined,
          }, size: 28),
        ),
      ),
      Text(preset.label),
    ],
  );
}
