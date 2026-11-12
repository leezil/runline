import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/app/app_colors.dart';
import 'package:runline/features/route_drawing/drawing_canvas.dart';
import 'package:runline/features/route_drawing/drawing_presets.dart';
import 'package:runline/features/route_drawing/route_drawing_screen.dart';
import 'package:runline/features/route_drawing/route_generation_screen.dart';

Future<Color> canvasPixel(WidgetTester tester, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(DrawingCanvas),
      matching: find.byType(RepaintBoundary),
    ),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final index = (point.dy.round() * image.width + point.dx.round()) * 4;
      return Color.fromARGB(
        bytes.getUint8(index + 3),
        bytes.getUint8(index),
        bytes.getUint8(index + 1),
        bytes.getUint8(index + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  testWidgets(
    'exclusive preset selection paints canvas and preserves range through generation/back',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RouteDrawingScreen()));
      final controller = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .controller;
      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(5, 8),
      );
      await tester.pump();
      for (final preset in DrawingPreset.values) {
        final button = find.byKey(ValueKey('preset-${preset.name}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(controller.selectedPreset, preset);
        for (final other in DrawingPreset.values) {
          final icon = tester.widget<IconButton>(
            find.byKey(ValueKey('preset-${other.name}')),
          );
          expect(icon.isSelected, other == preset);
          expect(
            icon.style!.side!.resolve({})!.color,
            other == preset ? AppColors.primary : AppColors.border,
          );
        }
        final drawing = controller.snapshot()!;
        expect(drawing.strokes, hasLength(1));
        expect(drawing.points, preset.pointsFor(drawing.canvasSize));
        expect(
          await canvasPixel(tester, drawing.points.first),
          AppColors.primary,
        );
        expect(find.text('5-8Km'), findsOneWidget);
        final entry = find.widgetWithText(FilledButton, '그림 찾기');
        expect(tester.widget<FilledButton>(entry).onPressed, isNotNull);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        final generation = tester.widget<RouteGenerationScreen>(
          find.byType(RouteGenerationScreen),
        );
        expect(generation.drawing.points, drawing.points);
        expect(generation.drawing.strokes, hasLength(1));
        expect(generation.minDistanceKm, 5);
        expect(generation.maxDistanceKm, 8);
        expect(
          tester.widget<DrawingPreview>(find.byType(DrawingPreview)).drawing,
          same(generation.drawing),
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(controller.selectedPreset, preset);
      }
      final lastPoint = controller.snapshot()!.points.first;
      await tester.ensureVisible(find.text('초기화'));
      await tester.tap(find.text('초기화'));
      await tester.pumpAndSettle();
      expect(controller.selectedPreset, isNull);
      expect(controller.snapshot(), isNull);
      expect(await canvasPixel(tester, lastPoint), Colors.white);
      for (final preset in DrawingPreset.values) {
        expect(
          tester
              .widget<IconButton>(find.byKey(ValueKey('preset-${preset.name}')))
              .isSelected,
          isFalse,
        );
      }
      expect(find.text('5-8Km'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '그림 찾기'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [ui.PointerDeviceKind.mouse, ui.PointerDeviceKind.touch]) {
    testWidgets('$kind drawing replaces preset and deselects the shape', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RouteDrawingScreen()));
      final presetButton = find.byKey(const ValueKey('preset-heart'));
      await tester.ensureVisible(presetButton);
      await tester.tap(presetButton);
      await tester.pumpAndSettle();
      final controller = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .controller;
      final origin = tester.getTopLeft(
        find.byKey(const Key('drawing-canvas-input')),
      );
      final gesture = await tester.startGesture(
        origin + const Offset(30, 30),
        kind: kind,
      );
      await gesture.moveTo(origin + const Offset(100, 80));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selectedPreset, isNull);
      expect(tester.widget<IconButton>(presetButton).isSelected, isFalse);
      expect(controller.snapshot()!.strokes, hasLength(1));
      expect(controller.snapshot()!.points, [
        const Offset(30, 30),
        const Offset(100, 80),
      ]);
      expect(
        await canvasPixel(tester, const Offset(100, 80)),
        AppColors.primary,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'preset refits after browser resize without distorting or changing the saved snapshot',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RouteDrawingScreen()));
      await tester.ensureVisible(find.byKey(const ValueKey('preset-star')));
      await tester.tap(find.byKey(const ValueKey('preset-star')));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .controller;
      final original = controller.snapshot()!;
      tester.view.physicalSize = const Size(1000, 720);
      await tester.pumpAndSettle();
      final resized = controller.snapshot()!;
      expect(resized.canvasSize, isNot(original.canvasSize));
      expect(resized.points, DrawingPreset.star.pointsFor(resized.canvasSize));
      expect(
        original.points,
        DrawingPreset.star.pointsFor(original.canvasSize),
      );
      expect(
        await canvasPixel(tester, resized.points.first),
        AppColors.primary,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
