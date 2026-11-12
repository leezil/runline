import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/route_generation/route_api.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';
import 'package:runline/features/route_recommendation/route_recommendation_screen.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/features/running/running_timer.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

import 'fake_running_history.dart';
import 'fake_running_location.dart';
import 'route_api_test.dart' as fixtures;
import 'running_history_test.dart' show historyFixture;

void main() {
  testWidgets(
    'API selection hands the same snapshot and lon/lat conversion to running map',
    (tester) async {
      final result = parseRoutes(
        fixtures.responseBody([
          fixtures.candidate(),
          fixtures.candidate(distance: 6200),
        ]),
      );
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
      final selected = result.last;
      await tester.ensureVisible(find.byKey(ValueKey(selected.id)));
      await tester.tap(find.byKey(ValueKey(selected.id)));
      await tester.pumpAndSettle();
      final start = find.byKey(const Key('route-running-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      final screen = tester.widget<RunningScreen>(find.byType(RunningScreen));
      expect(screen.selectedRoute, same(selected));
      final map = tester.widget<RunlineMapView>(find.byType(RunlineMapView));
      expect(map.routeCoordinates, same(selected.coordinates));
      expect(map.routeCoordinates.first.latitude, 37.5);
      expect(map.routeCoordinates.first.longitude, 127.1);
      expect(find.textContaining('추천 경로 러닝'), findsOneWidget);
      expect(find.text('목표 6.20 km'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RouteRecommendationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unfinished record is offered and restored paused before any GPS subscription',
    (tester) async {
      final history = FakeRunningHistory();
      await history.save(historyFixture());
      final source = FakeRunningLocation();
      late RunningTimer timer;
      await tester.pumpWidget(
        MaterialApp(
          home: RunningScreen(
            history: history,
            location: source,
            createTimer: () => timer = RunningTimer(now: () => Duration.zero),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('미완료 러닝'), findsOneWidget);
      expect(source.subscriptions, 0);
      await tester.tap(find.text('이어서 진행'));
      await tester.pumpAndSettle();
      expect(timer.status, RunningStatus.paused);
      expect(find.text('00:10'), findsOneWidget);
      expect(find.text('0.03 km'), findsOneWidget);
      expect(find.text('목표 5.00 km'), findsOneWidget);
      expect(source.subscriptions, 0);
      await tester.tap(find.text('종료'));
      await tester.pumpAndSettle();
      final saved = (await history.list(finished: true)).single;
      expect(saved.id, 'test-session');
      expect(saved.distanceMeters, 30);
      expect(await history.list(finished: false), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await source.controller.close();
    },
  );

  testWidgets('storage failure is visible and does not stop GPS timer', (
    tester,
  ) async {
    final source = FakeRunningLocation();
    final history = FakeRunningHistory()..failWrites = true;
    late RunningTimer timer;
    await tester.pumpWidget(
      MaterialApp(
        home: RunningScreen(
          history: history,
          location: source,
          createTimer: () => timer = RunningTimer(now: () => Duration.zero),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(timer.status, RunningStatus.running);
    expect(find.byKey(const Key('running-storage-error')), findsOneWidget);
    history.failWrites = false;
    await tester.tap(find.text('저장 다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('running-storage-error')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await source.controller.close();
  });
}
