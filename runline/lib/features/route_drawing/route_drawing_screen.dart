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

  static const routeName = 'Home_drawRoute';

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '달리고 싶은 그림을 그려보세요!',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: math.min(
                      420,
                      math.max(240, constraints.maxHeight - 300),
                    ),
                    child: DrawingCanvas(controller: _drawing),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('추천 모양', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  ListenableBuilder(
                    listenable: _drawing,
                    builder: (context, _) => Row(
                      children: [
                        for (final preset in DrawingPreset.values)
                          Expanded(
                            child: _ShapeAction(
                              preset: preset,
                              selected: _drawing.selectedPreset == preset,
                              onPressed: () => _drawing.selectPreset(preset),
                            ),
                          ),
                        Expanded(
                          child: _ShapeAction(
                            onPressed: _drawing.hasDrawing
                                ? _drawing.clear
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '거리 범위',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                    semanticFormatterCallback: (value) =>
                        '${value.toInt()} 킬로미터',
                    onChanged: (values) => setState(() {
                      minDistanceKm = values.start.roundToDouble();
                      maxDistanceKm = values.end.roundToDouble();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListenableBuilder(
                    listenable: _drawing,
                    builder: (context, _) => Center(
                      child: FilledButton(
                        onPressed: _drawing.hasDrawing ? _prepareDrawing : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(164, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('그림 찾기'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ShapeAction extends StatelessWidget {
  const _ShapeAction({
    this.preset,
    this.selected = false,
    required this.onPressed,
  });

  final DrawingPreset? preset;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = preset?.label ?? '초기화';
    final icon = switch (preset) {
      DrawingPreset.star => Icons.star_outline_rounded,
      DrawingPreset.heart => Icons.favorite_border,
      DrawingPreset.crescent => Icons.dark_mode_outlined,
      null => Icons.restart_alt,
    };
    return Center(
      child: Semantics(
        selected: preset == null ? null : selected,
        child: IconButton.filled(
          key: preset == null ? null : ValueKey('preset-${preset!.name}'),
          onPressed: onPressed,
          isSelected: selected,
          tooltip: label,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(56),
            fixedSize: const Size.square(56),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            backgroundColor: selected
                ? AppColors.primary
                : const Color(0xFF657EE4),
            foregroundColor: Colors.white,
          ),
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
