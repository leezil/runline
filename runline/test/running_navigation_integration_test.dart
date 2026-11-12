import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';
import 'package:runline/features/running/running_controller.dart';
import 'package:runline/features/running/running_location.dart';
import 'package:runline/features/running/running_timer.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/features/running/route_navigation.dart';
import 'package:runline/features/running/history/running_record.dart';
import 'package:runline/features/running/history/running_history_repository.dart';
import 'package:runline/features/running/history/running_session_recorder.dart';
import 'package:runline/features/running/history/running_record_detail_screen.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';
import 'package:runline/shared/widgets/running_map_data.dart';

import 'fake_running_history.dart';
import 'fake_running_location.dart';
import 'running_history_test.dart' show historyFixture;

final epoch = DateTime.utc(2026);
RecommendedRoute course() => RecommendedRoute(
  id: 'real-api-fixture',
  name: '서버 코스',
  distanceKm: 5,
  estimatedDuration: Duration.zero,
  source: RouteDataSource.api,
  coordinates: [const LatLng(0, 0), const LatLng(0, 100 / 111195)],
);
GpsPoint point(
  double meters,
  int seconds, {
  double north = 0,
  double accuracy = 3,
}) => GpsPoint(
  north / 111195,
  meters / 111195,
  accuracy,
  epoch.add(Duration(seconds: seconds)),
);

void main() {
  testWidgets(
    'storage open failure can be retried after finish without discarding GPS',
    (tester) async {
      final source = FakeRunningLocation();
      final repository = FakeRunningHistory();
      RunningHistory.open = () async =>
          throw StateError('fixture storage failure');
      await tester.pumpWidget(
        MaterialApp(home: RunningScreen(location: source)),
      );
      await tester.pumpAndSettle();
      final now = DateTime.now();
      source.controller.add(
        GpsPoint(0, 0, 3, now.subtract(const Duration(seconds: 4))),
      );
      source.controller.add(
        GpsPoint(0, 10 / 111195, 3, now.subtract(const Duration(seconds: 1))),
      );
      await tester.pump();
      await tester.tap(find.text('종료'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('running-storage-error')), findsOneWidget);
      expect(find.byKey(const Key('open-running-record')), findsNothing);
      RunningHistory.open = () async => repository;
      final retry = find.text('저장 다시 시도');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      final saved = (await repository.list(finished: true)).single;
      expect(saved.points, hasLength(2));
      expect(saved.distanceMeters, closeTo(10, .1));
      expect(find.byKey(const Key('open-running-record')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await source.controller.close();
    },
  );
  test(
    'free run has no route logic, persists and restores segmented GPS',
    () async {
      final source = FakeRunningLocation(), repository = FakeRunningHistory();
      var now = epoch;
      final run = RunningController(
        location: source,
        timer: RunningTimer(now: () => Duration.zero),
        now: () => now,
      );
      final recorder = RunningSessionRecorder(run: run, repository: repository);
      await run.startOrResume();
      source.controller.add(point(0, 0));
      now = epoch.add(const Duration(seconds: 2));
      source.controller.add(point(10, 2));
      expect(run.currentPosition!.longitude, closeTo(10 / 111195, 1e-10));
      expect(run.navigation, isNull);
      expect(run.trackSegments, hasLength(1));
      run.pause();
      now = epoch.add(const Duration(seconds: 4));
      source.controller.add(point(500, 4));
      expect(run.measurement.pointCount, 2);
      await run.startOrResume();
      source.controller.add(point(500, 4));
      now = epoch.add(const Duration(seconds: 6));
      source.controller.add(point(510, 6));
      expect(run.trackSegments, hasLength(2));
      expect(run.measurement.distanceMeters, closeTo(20, .1));
      recorder.checkpoint();
      await recorder.flush();
      final saved = (await repository.list(finished: false)).single;
      expect(saved.route, isNull);
      expect(saved.passage, isNull);
      expect(saved.segmentStarts, [0, 2]);
      recorder.dispose();
      run.dispose();
      final restored = RunningController(
        location: source,
        timer: RunningTimer(now: () => Duration.zero),
      );
      restored.restore(saved);
      expect(restored.timer.status, RunningStatus.paused);
      expect(restored.trackSegments, hasLength(2));
      expect(restored.currentPosition, isNull);
      expect(restored.navigation, isNull);
      restored.dispose();
      await source.controller.close();
    },
  );
  test('filtered jumps never move marker, trail or passage; poor accuracy breaks passage', () async {
    final source = FakeRunningLocation();
    var now = epoch;
    final run = RunningController(
      location: source,
      timer: RunningTimer(),
      route: course(),
      now: () => now,
    );
    await run.startOrResume();
    source.controller.add(point(0, 0));
    now = epoch.add(const Duration(seconds: 2));
    source.controller.add(point(10, 2));
    final passed = run.navigation!.passedMeters;
    now = epoch.add(const Duration(seconds: 3));
    source.controller.add(point(1000, 3));
    expect(run.currentPosition!.longitude, closeTo(10 / 111195, 1e-10));
    expect(run.measurement.pointCount, 2);
    expect(run.navigation!.passedMeters, passed);
    now = epoch.add(const Duration(seconds: 5));
    source.controller.add(point(20, 5, accuracy: 80));
    now = epoch.add(const Duration(seconds: 7));
    source.controller.add(point(30, 7));
    expect(run.trackSegments, hasLength(2));
    expect(run.navigation!.passedMeters, passed);
    run.dispose();
    await source.controller.close();
  });
  test('new passage metadata survives database close/reopen and leaves legacy schema readable', () async {
    final factory = newDatabaseFactoryMemory();
    var repository = RunningHistoryRepository(
      await factory.openDatabase('nav'),
    );
    final nav = RouteNavigation(course().coordinates);
    nav.add(point(0, 0));
    nav.add(point(10, 2));
    final old = historyFixture(route: course());
    final record = RunningRecord(
      id: old.id,
      startedAt: old.startedAt,
      updatedAt: old.updatedAt,
      revision: old.revision,
      status: RunningStatus.finished,
      activeTime: old.activeTime,
      distanceMeters: old.distanceMeters,
      points: old.points,
      segmentStarts: old.segmentStarts,
      route: old.route,
      passage: nav.snapshot,
    );
    await repository.save(record);
    await repository.close();
    repository = RunningHistoryRepository(await factory.openDatabase('nav'));
    final saved = (await repository.read(record.id))!;
    expect(saved.passage, isNotNull);
    expect(saved.courseProgress, closeTo(.1, .001));
    expect(saved.courseCompleted, isFalse);
    expect(saved.averagePace, "05'33\"");
    final legacy = Map<String, Object?>.from(record.toJson())
      ..remove('navigation');
    expect(RunningRecord.fromJson(legacy).courseProgress, isNull);
    expect(RunningRecord.fromJson(legacy).points, hasLength(2));
    await repository.close();
  });
  testWidgets(
    'map receives live location and split trails; gesture suspends follow, button restores it',
    (tester) async {
      final source = FakeRunningLocation();
      await tester.pumpWidget(
        MaterialApp(
          home: RunningScreen(location: source, history: FakeRunningHistory()),
        ),
      );
      await tester.pumpAndSettle();
      final now = DateTime.now();
      source.controller.add(
        GpsPoint(0, 0, 3, now.subtract(const Duration(seconds: 6))),
      );
      await tester.pump();
      source.controller.add(
        GpsPoint(0, 10 / 111195, 3, now.subtract(const Duration(seconds: 3))),
      );
      await tester.pump();
      RunlineMapView map() =>
          tester.widget<RunlineMapView>(find.byType(RunlineMapView));
      expect(map().currentPosition, isNotNull);
      expect(map().trackSegments.single, hasLength(2));
      expect(map().followLocation, isTrue);
      map().onUserGesture!();
      await tester.pump();
      expect(map().followLocation, isFalse);
      await tester.tap(find.byKey(const Key('recenter-location')));
      await tester.pump();
      expect(map().followLocation, isTrue);
      expect(map().recenterToken, 1);
      await tester.tap(find.text('일시정지'));
      await tester.pump();
      source.controller.add(
        GpsPoint(0, 500 / 111195, 3, now.subtract(const Duration(seconds: 1))),
      );
      await tester.pump();
      expect(map().trackSegments.single, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      await source.controller.close();
    },
  );
  testWidgets(
    'detail renders both saved routes, passage and pause boundaries; comparison can be toggled',
    (tester) async {
      final repository = FakeRunningHistory();
      final nav = RouteNavigation(course().coordinates);
      nav.add(point(0, 0));
      nav.add(point(10, 2));
      final record = RunningRecord(
        id: 'detail',
        startedAt: epoch,
        updatedAt: epoch,
        revision: 1,
        status: RunningStatus.finished,
        activeTime: const Duration(seconds: 20),
        distanceMeters: 20,
        points: [point(0, 0), point(10, 2), point(30, 6), point(40, 8)],
        segmentStarts: [0, 2],
        route: course(),
        passage: nav.snapshot,
      );
      await repository.save(record);
      await tester.pumpWidget(
        MaterialApp(
          home: RunningRecordDetailScreen(
            recordId: record.id,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      RunlineMapView map() =>
          tester.widget<RunlineMapView>(find.byType(RunlineMapView));
      expect(map().routeCoordinates, hasLength(2));
      expect(map().trackSegments, hasLength(2));
      expect(map().completedRouteSegments, hasLength(1));
      expect(map().followLocation, isFalse);
      expect(find.textContaining('10.0%'), findsOneWidget);
      await tester.tap(find.text('추천 코스'));
      await tester.pump();
      expect(map().routeCoordinates, isEmpty);
      expect(map().trackSegments, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'legacy course details show unavailable passage; free detail has no course UI',
    (tester) async {
      final repository = FakeRunningHistory();
      await repository.save(historyFixture(route: course()));
      await tester.pumpWidget(
        MaterialApp(
          home: RunningRecordDetailScreen(
            recordId: 'test-session',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이전 기록: 코스 통과 정보 없음'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final free = FakeRunningHistory();
      await free.save(historyFixture());
      await tester.pumpWidget(
        MaterialApp(
          home: RunningRecordDetailScreen(
            recordId: 'test-session',
            repository: free,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('자유 러닝 기록'), findsOneWidget);
      expect(find.byKey(const Key('record-passage')), findsNothing);
      expect(
        tester
            .widget<RunlineMapView>(find.byType(RunlineMapView))
            .trackSegments,
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('render layers keep free trails green, route trails purple, and passage green', () {
    final track = [const LatLng(0, 0), const LatLng(0, .001)];
    final free = runningMapLines(
      route: [],
      tracks: [track],
      passed: [],
      direction: [],
      routeRun: false,
    );
    expect(free.single.color, passageGreen);
    final route = runningMapLines(
      route: track,
      tracks: [track],
      passed: [track],
      direction: [],
      routeRun: true,
    );
    expect(route.map((e) => e.color), [actualPurple, routeBlue, passageGreen]);
  });
}
