import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/app/kakao_map_bootstrap.dart';
import 'package:runline/features/route_drawing/route_drawing_screen.dart';
import 'package:runline/features/route_drawing/drawing_canvas.dart';
import 'package:runline/features/route_drawing/drawing_controller.dart';
import 'package:runline/features/route_drawing/route_generation_screen.dart';
import 'package:runline/app/app_colors.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/main.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

void main() {
  for (final abi in ['android_x64', 'android_arm64']) {
    testWidgets('route drawing is a blank canvas and returns home on $abi', (
      tester,
    ) async {
      await KakaoMapBootstrap.initialize(
        nativeAppKey: '',
        abiProvider: () => abi,
      );
      await tester.pumpWidget(const RunlineApp());
      await tester.ensureVisible(find.text('루트그리기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('루트그리기'));
      await tester.pumpAndSettle();

      expect(find.byType(RouteDrawingScreen), findsOneWidget);
      expect(find.text('루트 그리기'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(RunlineMapView), findsNothing);
      expect(find.byType(KakaoMap, skipOffstage: false), findsNothing);
      expect(
        find.text(
          abi == 'android_x64'
              ? '카카오맵은 ARM64 기기에서 확인할 수 있습니다'
              : '지도를 사용하려면 앱 키 설정이 필요합니다.',
        ),
        findsNothing,
      );
      final canvas = find.byType(DrawingCanvas);
      expect(tester.getSize(canvas).height, greaterThanOrEqualTo(240));
      expect(tester.getSize(canvas).width, greaterThan(0));
      expect(find.text('달리고 싶은 그림을 그려보세요!'), findsOneWidget);
      expect(find.text('추천 모양'), findsOneWidget);
      expect(find.text('거리 범위'), findsOneWidget);
      expect(find.text('4-8Km'), findsOneWidget);
      expect(find.text('초기화'), findsOneWidget);
      expect(find.text('그림 찾기'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RouteDrawingScreen), findsNothing);
      expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );

      await tester.ensureVisible(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningScreen), findsOneWidget);
      expect(find.text('러닝 시작 준비'), findsOneWidget);
      await tester.tap(find.text('종료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'distance handles update numeric range and label without drawing',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RouteDrawingScreen()));
      final sliderFinder = find.byType(RangeSlider);
      await tester.ensureVisible(sliderFinder);
      await tester.pumpAndSettle();
      var slider = tester.widget<RangeSlider>(sliderFinder);
      expect(slider.min, 1);
      expect(slider.max, 15);
      expect(slider.values, const RangeValues(4, 8));
      expect(find.text('4-8Km'), findsOneWidget);

      final rect = tester.getRect(sliderFinder);
      final trackWidth = rect.width - 48;
      await tester.dragFrom(
        Offset(rect.left + 24 + trackWidth * 3 / 14, rect.center.dy),
        Offset(trackWidth / 14, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<RangeSlider>(sliderFinder).values,
        const RangeValues(5, 8),
      );
      expect(find.text('5-8Km'), findsOneWidget);
      await tester.dragFrom(
        Offset(rect.left + 24 + trackWidth * 7 / 14, rect.center.dy),
        Offset(trackWidth * 2 / 14, 0),
      );
      await tester.pumpAndSettle();
      slider = tester.widget<RangeSlider>(sliderFinder);
      expect(slider.values, const RangeValues(5, 10));
      expect(find.text('5-10Km'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      for (final label in ['별', '하트', '초승달']) {
        final button = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == label,
        );
        expect(button, findsOneWidget);
        expect(tester.widget<IconButton>(button).onPressed, isNotNull);
        expect(tester.widget<IconButton>(button).isSelected, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [ui.PointerDeviceKind.mouse, ui.PointerDeviceKind.touch]) {
    testWidgets('$kind paints live blue strokes, exports points and clears', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DrawingData? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: RouteDrawingScreen(onDrawingReady: (data) => submitted = data),
        ),
      );
      final canvasFinder = find.byType(DrawingCanvas);
      final controller = tester.widget<DrawingCanvas>(canvasFinder).controller;
      final input = find.byKey(const Key('drawing-canvas-input'));
      final origin = tester.getTopLeft(input);

      Future<Color> pixelAt(int x, int y, {Finder? preview}) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.descendant(
            of: preview ?? canvasFinder,
            matching: find.byType(RepaintBoundary),
          ),
        );
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final index = (y * image.width + x) * 4;
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

      expect(await pixelAt(100, 100), Colors.white);
      expect(controller.hasDrawing, isFalse);
      final gesture = await tester.startGesture(
        origin + const Offset(40, 40),
        kind: kind,
      );
      await gesture.moveTo(origin + const Offset(75, 75));
      await gesture.moveTo(origin + const Offset(100, 100));
      await gesture.moveTo(origin + const Offset(150, 100));
      await tester.pump();
      // Assert actual painted pixels while the pointer is still held down.
      expect(await pixelAt(100, 100), AppColors.primary);
      expect(controller.snapshot()!.points.length, greaterThan(1));
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await gesture.up();
      await tester.pump();
      final secondStroke = await tester.startGesture(
        origin + const Offset(220, 180),
        kind: kind,
      );
      await secondStroke.up();
      await tester.pump();
      final original = controller.snapshot()!;
      final count = controller.snapshot()!.points.length;
      if (kind == ui.PointerDeviceKind.mouse) {
        await tester.sendEventToBinding(
          PointerHoverEvent(
            position: origin + const Offset(200, 200),
            kind: kind,
          ),
        );
      }
      await tester.pump();
      expect(controller.snapshot()!.points.length, count);

      tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
        const RangeValues(5, 10),
      );
      await tester.pump();
      expect(controller.snapshot()!.strokes, original.strokes);
      await tester.ensureVisible(find.text('그림 찾기'));
      await tester.tap(find.text('그림 찾기'));
      await tester.pumpAndSettle();
      expect(submitted, isNotNull);
      final screen = tester.widget<RouteGenerationScreen>(
        find.byType(RouteGenerationScreen),
      );
      expect(screen.drawing, same(submitted));
      expect(screen.minDistanceKm, 5);
      expect(screen.maxDistanceKm, 10);
      expect(screen.drawing.canvasSize, original.canvasSize);
      expect(screen.drawing.strokes, original.strokes);
      expect(screen.drawing.points, original.points);
      expect(submitted!.strokes.length, 2);
      expect(submitted!.points.first, const Offset(40, 40));
      expect(find.text('경로 만들기'), findsOneWidget);
      expect(find.text('그린 모양을 바탕으로 러닝 경로를 생성할 준비가 되었습니다.'), findsOneWidget);
      expect(find.text('전체 point 개수: $count개'), findsOneWidget);
      expect(find.byKey(const Key('target-distance')), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final preview = find.byType(DrawingPreview);
      expect(tester.widget<DrawingPreview>(preview).drawing, same(submitted));
      expect(await pixelAt(100, 100, preview: preview), AppColors.primary);
      expect(await pixelAt(220, 180, preview: preview), AppColors.primary);
      expect(await pixelAt(185, 140, preview: preview), Colors.white);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RouteGenerationScreen), findsNothing);
      expect(find.text('5-10Km'), findsOneWidget);
      expect(controller.snapshot()!.strokes, original.strokes);
      expect(controller.snapshot()!.points, original.points);
      expect(await pixelAt(100, 100), AppColors.primary);
      expect(await pixelAt(220, 180), AppColors.primary);
      await tester.tap(find.text('초기화'));
      await tester.pump();
      expect(controller.snapshot(), isNull);
      expect(await pixelAt(100, 100), Colors.white);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        submitted!.points.length,
        count,
      ); // Prepared snapshots survive reset.
      expect(tester.takeException(), isNull);
    });
  }
}
