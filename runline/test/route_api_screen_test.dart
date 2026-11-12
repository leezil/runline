import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/route_drawing/route_generation_screen.dart';
import 'package:runline/features/route_generation/route_api.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';
import 'package:runline/features/route_recommendation/route_recommendation_screen.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

import 'route_api_test.dart' as fixtures;

class FakeRoutes implements RouteService {
  final pending = Completer<RouteResult>();
  int calls = 0;
  RouteRequest? request;
  @override
  Future<RouteResult> generate(RouteRequest input) {
    calls++;
    request = input;
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> health() async => {'status': 'ok'};
  @override
  void close() {}
}

void main() {
  testWidgets(
    'empty response shows server message, warnings and actual counts',
    (tester) async {
      final result = parseRoutes({
        ...fixtures.responseBody([
          fixtures.candidate(acceptable: false),
        ], found: false),
        'recommended_count': 0,
        'message': '거리 조건 불일치',
        'request_id': 'example-id',
        'warnings': ['탐색 종료'],
        'data': {
          'warnings': ['도로 경고'],
        },
      }, httpStatus: 200);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteRecommendationScreen(
            input: RouteGenerationInput(
              drawing: fixtures.sampleDrawing(),
              minDistanceKm: 4,
              maxDistanceKm: 8,
            ),
            routes: result,
            result: result,
          ),
        ),
      );
      expect(find.text('서버 안내: 거리 조건 불일치'), findsOneWidget);
      expect(find.text('서버 경고: 탐색 종료'), findsOneWidget);
      expect(find.textContaining('도로 데이터 경고:'), findsOneWidget);
      await tester.ensureVisible(find.text('요청·응답 확인'));
      await tester.tap(find.text('요청·응답 확인'));
      await tester.pumpAndSettle();
      expect(find.text('POST /v1/routes · HTTP 200'), findsOneWidget);
      expect(
        find.text('candidates: 1 · acceptable=true: 0 · 표시 추천: 0'),
        findsOneWidget,
      );
      expect(find.text('비교 1 · acceptable=false'), findsOneWidget);
      expect(find.byType(RunlineMapView), findsNothing);
    },
  );

  testWidgets(
    'synthetic result never renders OSM map or selectable recommendation',
    (tester) async {
      final result = parseRoutes({
        ...fixtures.responseBody([fixtures.candidate()]),
        'source': 'synthetic',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: RouteRecommendationScreen(
            input: RouteGenerationInput(
              drawing: fixtures.sampleDrawing(),
              minDistanceKm: 4,
              maxDistanceKm: 8,
            ),
            routes: result,
            result: result,
          ),
        ),
      );
      expect(find.textContaining('synthetic 가상 도로'), findsOneWidget);
      expect(find.textContaining('© OpenStreetMap'), findsNothing);
      expect(find.byType(RunlineMapView), findsNothing);
      expect(find.byKey(const ValueKey('api-route-0')), findsNothing);
    },
  );
  final input = RouteGenerationInput(
    drawing: fixtures.sampleDrawing(),
    minDistanceKm: 4,
    maxDistanceKm: 8,
  );

  testWidgets(
    'actual candidates have separate distances; selections replace map coordinates',
    (tester) async {
      final routes = parseRoutes(
        fixtures.responseBody([
          fixtures.candidate(),
          fixtures.candidate(distance: 6210, approach: 750),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RouteRecommendationScreen(input: input, routes: routes),
        ),
      );
      expect(
        find.textContaining('© OpenStreetMap contributors'),
        findsOneWidget,
      );
      expect(find.textContaining('실제 코스 거리 5125.0 m'), findsOneWidget);
      expect(find.textContaining('접근 거리 124.5 m'), findsOneWidget);
      expect(find.textContaining('Mock'), findsNothing);
      expect(
        tester
            .widget<RunlineMapView>(find.byType(RunlineMapView))
            .routeCoordinates,
        same(routes.first.coordinates),
      );
      await tester.ensureVisible(find.byKey(ValueKey(routes.last.id)));
      await tester.tap(find.byKey(ValueKey(routes.last.id)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RunlineMapView>(find.byType(RunlineMapView))
            .routeCoordinates,
        same(routes.last.coordinates),
      );
      expect(find.text('선택 경로: 추천 2 · OSM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty actual results show guidance without mock cards or map', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RouteRecommendationScreen(input: input, routes: const []),
      ),
    );
    expect(find.byKey(const Key('empty-routes')), findsOneWidget);
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.byType(RunlineMapView), findsNothing);
    expect(find.byKey(const ValueKey('mock-route-1')), findsNothing);
  });

  testWidgets(
    'requires explicit target and location, preserves range and blocks duplicates',
    (tester) async {
      final service = FakeRoutes();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteGenerationScreen(
            drawing: input.drawing,
            minDistanceKm: 4,
            maxDistanceKm: 8,
            service: service,
          ),
        ),
      );
      final generate = find.widgetWithText(FilledButton, '경로 생성');
      Future<void> submit() async {
        await tester.ensureVisible(generate);
        await tester.tap(generate);
        await tester.pump();
      }

      Future<void> enter(String key, String value) async {
        final field = find.byKey(Key(key));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await submit();
      expect(service.calls, 0);
      expect(find.textContaining('직접 입력해주세요.'), findsOneWidget);
      await enter('target-distance', '5.125');
      await tester.ensureVisible(find.text('세부 탐색 설정'));
      await tester.tap(find.text('세부 탐색 설정'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('search-radius_m')));
      await tester.enterText(
        find.byKey(const ValueKey('search-radius_m')),
        '3000',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('search-search_seconds')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('search-search_seconds')),
        '15',
      );
      await submit();
      expect(service.calls, 0);
      expect(find.textContaining('현재 GPS 위치는 사용하지 않습니다.'), findsOneWidget);
      await enter('test-longitude', '127.1');
      await enter('test-latitude', '37.5');
      await enter('target-distance', '9');
      await submit();
      expect(service.calls, 0);
      await enter('target-distance', '5.125');
      await submit();
      expect(service.calls, 1);
      expect(service.request!.input.minDistanceKm, 4);
      expect(service.request!.input.maxDistanceKm, 8);
      expect(service.request!.input.drawing, same(input.drawing));
      expect(service.request!.toJson()['distance_m'], 5125);
      expect(service.request!.toJson()['radius_m'], 3000);
      expect(service.request!.toJson()['search_seconds'], 15);
      expect(tester.widget<FilledButton>(generate).onPressed, isNull);
      await submit();
      expect(service.calls, 1);
      service.pending.complete(
        parseRoutes(fixtures.responseBody([fixtures.candidate()])),
      );
      await tester.pumpAndSettle();
      expect(find.text('추천 1 · OSM'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
    },
  );

  testWidgets(
    'failed API request keeps generation screen and never opens mock result',
    (tester) async {
      final service = FakeRoutes();
      await tester.pumpWidget(
        MaterialApp(
          home: RouteGenerationScreen(drawing: input.drawing, service: service),
        ),
      );
      for (final entry in {
        'target-distance': '5',
        'test-longitude': '127',
        'test-latitude': '37',
      }.entries) {
        await tester.ensureVisible(find.byKey(Key(entry.key)));
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
      final generate = find.widgetWithText(FilledButton, '경로 생성');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pump();
      service.pending.completeError(const RouteApiException('인증 실패 (401)'));
      await tester.pumpAndSettle();
      expect(find.text('인증 실패 (401)'), findsOneWidget);
      expect(find.byType(RouteRecommendationScreen), findsNothing);
      expect(find.byKey(const ValueKey('mock-route-1')), findsNothing);
      expect(tester.widget<FilledButton>(generate).onPressed, isNotNull);
    },
  );
}
