import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/app/app_colors.dart';
import 'package:runline/features/route_drawing/drawing_controller.dart';
import 'package:runline/features/route_drawing/route_generation_screen.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';
import 'package:runline/features/route_recommendation/route_recommendation_screen.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

void main() {
  final drawing = DrawingData(
    canvasSize: const Size(300, 300),
    strokes: [
      [const Offset(10, 20), const Offset(100, 120)],
    ],
  );
  final input = RouteGenerationInput(
    drawing: drawing,
    minDistanceKm: 5,
    maxDistanceKm: 10,
  );

  test(
    'mock routes have distinct IDs, immutable coordinates and explicit source',
    () {
      expect(mockRecommendedRoutes, hasLength(3));
      expect(mockRecommendedRoutes.map((r) => r.id).toSet(), hasLength(3));
      for (final route in mockRecommendedRoutes) {
        expect(route.isMock, isTrue);
        expect(route.distanceKm, greaterThan(0));
        expect(route.estimatedDuration.inMinutes, greaterThan(0));
        expect(route.coordinates.length, greaterThanOrEqualTo(2));
        expect(() => route.coordinates.clear(), throwsUnsupportedError);
      }
      expect(() => mockRecommendedRoutes.clear(), throwsUnsupportedError);
      final coordinates = [
        const LatLng(37.4, 127.1),
        const LatLng(37.41, 127.11),
      ];
      final route = RecommendedRoute(
        id: 'domain-route',
        name: 'API domain example',
        distanceKm: 5.5,
        estimatedDuration: const Duration(minutes: 40),
        coordinates: coordinates,
        source: RouteDataSource.api,
      );
      coordinates.clear();
      expect(route.coordinates, hasLength(2));
      expect(route.isMock, isFalse);
      expect(route.source, RouteDataSource.api);
      expect(input.drawing, same(drawing));
      expect(input.minDistanceKm, 5);
      expect(input.maxDistanceKm, 10);
      expect(RunningScreen(selectedRoute: route).selectedRoute, same(route));
    },
  );

  testWidgets(
    'three cards select, highlight and update the map input without starting a run',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RouteRecommendationScreen(input: input)),
      );
      for (var i = 1; i <= 3; i++) {
        expect(find.text('추천 $i · Mock'), findsOneWidget);
      }
      Material card(int index) =>
          tester.widget<Material>(find.byKey(ValueKey('mock-route-$index')));
      Color border(int index) =>
          (card(index).shape! as RoundedRectangleBorder).side.color;
      expect(border(1), AppColors.primary);
      expect(
        tester
            .widget<RunlineMapView>(find.byType(RunlineMapView))
            .routeCoordinates,
        same(mockRecommendedRoutes.first.coordinates),
      );
      for (final i in [2, 3, 1]) {
        await tester.ensureVisible(find.byKey(ValueKey('mock-route-$i')));
        await tester.tap(find.byKey(ValueKey('mock-route-$i')));
        await tester.pumpAndSettle();
        expect(border(i), AppColors.primary);
        for (var other = 1; other <= 3; other++) {
          if (other != i) expect(border(other), AppColors.border);
        }
        expect(find.text('선택됨'), findsOneWidget);
        expect(
          tester
              .widget<RunlineMapView>(find.byType(RunlineMapView))
              .routeCoordinates,
          same(mockRecommendedRoutes[i - 1].coordinates),
        );
      }
      expect(find.text('개발용 Mock Data · 실제 추천 경로가 아닙니다.'), findsOneWidget);
      final start = find.widgetWithText(FilledButton, '러닝 시작');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();
      expect(find.byType(RunningScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview preserves drawing and distance range through recommendation and back',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RouteGenerationScreen(
            drawing: drawing,
            minDistanceKm: 5,
            maxDistanceKm: 10,
          ),
        ),
      );
      expect(
        tester.widget<DrawingPreview>(find.byType(DrawingPreview)).drawing,
        same(drawing),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '경로 생성'))
            .onPressed,
        isNull,
      );
      final entry = find.text('추천 화면 미리보기');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final screen = tester.widget<RouteRecommendationScreen>(
        find.byType(RouteRecommendationScreen),
      );
      expect(screen.input.drawing, same(drawing));
      expect(screen.input.minDistanceKm, 5);
      expect(screen.input.maxDistanceKm, 10);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<DrawingPreview>(find.byType(DrawingPreview)).drawing,
        same(drawing),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'preview and recommendation scroll without overflow at 280x480, text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(280, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RouteGenerationScreen(drawing: drawing),
          ),
        );
        await tester.ensureVisible(find.text('추천 화면 미리보기'));
        await tester.tap(find.text('추천 화면 미리보기'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('추천 3 · Mock'));
        await tester.tap(find.text('추천 3 · Mock'));
        await tester.pump();
        await tester.ensureVisible(find.text('러닝 시작'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
