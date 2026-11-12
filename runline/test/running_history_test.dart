import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';
import 'package:runline/features/running/history/running_history_repository.dart';
import 'package:runline/features/running/history/running_record.dart';
import 'package:runline/features/running/history/running_session_recorder.dart';
import 'package:runline/features/running/running_controller.dart';
import 'package:runline/features/running/running_goal.dart';
import 'package:runline/features/running/running_location.dart';
import 'package:runline/features/running/running_timer.dart';

import 'fake_running_history.dart';
import 'fake_running_location.dart';

final historyEpoch = DateTime.utc(2026, 1, 1);
RunningRecord historyFixture({
  int revision = 1,
  RunningStatus status = RunningStatus.running,
  RecommendedRoute? route,
}) => RunningRecord(
  id: 'test-session',
  startedAt: historyEpoch,
  updatedAt: historyEpoch.add(Duration(seconds: revision)),
  revision: revision,
  status: status,
  activeTime: const Duration(seconds: 10),
  distanceMeters: 30,
  points: [
    GpsPoint(0, 0, 3, historyEpoch),
    GpsPoint(0.00027, 0, 3, historyEpoch.add(const Duration(seconds: 10))),
  ],
  segmentStarts: [0],
  goal: const RunningGoal.distance(5),
  route: route,
);

void main() {
  test('transactional upsert rejects duplicate/stale writes and immutable final overwrites', () async {
    final repository = RunningHistoryRepository(
      await databaseFactoryMemory.openDatabase('upsert'),
    );
    addTearDown(repository.close);
    await Future.wait([
      repository.save(historyFixture(revision: 2)),
      repository.save(historyFixture(revision: 1)),
      repository.save(historyFixture(revision: 2)),
    ]);
    expect((await repository.read('test-session'))!.revision, 2);
    expect(await repository.list(finished: false), hasLength(1));
    await repository.save(
      historyFixture(revision: 3, status: RunningStatus.finished),
    );
    await repository.save(historyFixture(revision: 4));
    expect(await repository.list(finished: false), isEmpty);
    expect(await repository.list(finished: true), hasLength(1));
    expect((await repository.read('test-session'))!.revision, 3);
  });

  test('native file database survives close/reopen with GPS, goals and route coordinates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'runline-history-test-',
    );
    final path = '${directory.path}/running.db';
    final route = RecommendedRoute(
      id: 'api-test',
      name: '코스',
      distanceKm: 5,
      estimatedDuration: const Duration(minutes: 30),
      source: RouteDataSource.api,
      coordinates: [const LatLng(37.5, 127.1), const LatLng(37.6, 127.2)],
    );
    var repository = RunningHistoryRepository(
      await databaseFactoryIo.openDatabase(path),
    );
    await repository.save(historyFixture(route: route));
    await repository.close();
    repository = RunningHistoryRepository(
      await databaseFactoryIo.openDatabase(path),
    );
    try {
      final record = (await repository.list(finished: false)).single;
      expect(record.distanceMeters, 30);
      expect(record.activeTime, const Duration(seconds: 10));
      expect(record.points, hasLength(2));
      expect(record.segmentStarts, [0]);
      expect((record.goal as DistanceGoal).distanceKm, 5);
      expect(record.route!.coordinates.first.latitude, 37.5);
      expect(record.route!.coordinates.first.longitude, 127.1);
      expect(record.route!.canRun, isTrue);
    } finally {
      await repository.close();
      await databaseFactoryIo.deleteDatabase(path);
      await directory.delete();
    }
  });

  test(
    'duration goal roundtrip and mock source cannot become a real route',
    () {
      final base = historyFixture(route: mockRecommendedRoutes.first).toJson();
      base['goal'] = {
        'microseconds': const Duration(minutes: 20).inMicroseconds,
      };
      final record = RunningRecord.fromJson(base);
      expect(
        (record.goal as DurationGoal).duration,
        const Duration(minutes: 20),
      );
      expect(record.route!.canRun, isFalse);
      expect(record.route!.isMock, isTrue);
      expect(() => record.points.clear(), throwsUnsupportedError);
    },
  );

  test('unfinished session restores paused, excludes downtime and starts a fresh GPS segment', () async {
    var active = Duration.zero;
    final source = FakeRunningLocation();
    final run = RunningController(
      location: source,
      timer: RunningTimer(now: () => active),
      now: () => historyEpoch.add(const Duration(hours: 1)).add(active),
    );
    run.restore(historyFixture());
    expect(run.timer.status, RunningStatus.paused);
    expect(run.timer.elapsed, const Duration(seconds: 10));
    expect(run.pace, "05'33\"");
    final repository = RunningHistoryRepository(
      await databaseFactoryMemory.openDatabase('recover'),
    );
    final recorder = RunningSessionRecorder(
      run: run,
      repository: repository,
      restored: historyFixture(),
    );
    try {
      await run.startOrResume();
      source.controller.add(
        GpsPoint(1, 0, 3, historyEpoch.add(const Duration(hours: 1))),
      );
      expect(run.measurement.distanceMeters, 30);
      active += const Duration(seconds: 5);
      source.controller.add(
        GpsPoint(
          1.0001,
          0,
          3,
          historyEpoch.add(const Duration(hours: 1, seconds: 5)),
        ),
      );
      await run.finish();
      await recorder.flush();
      final saved = (await repository.list(finished: true)).single;
      expect(saved.id, 'test-session');
      expect(saved.activeTime, const Duration(seconds: 15));
      expect(saved.distanceMeters, closeTo(41.119, 0.01));
      expect(saved.segmentStarts, [0, 2]);
    } finally {
      recorder.dispose();
      run.dispose();
      await source.controller.close();
      await repository.close();
    }
  });

  test('recorder checkpoints transitions, retries failures and preserves unfinished on exit', () async {
    final source = FakeRunningLocation();
    final repository = FakeRunningHistory()..failWrites = true;
    final run = RunningController(location: source, timer: RunningTimer());
    final recorder = RunningSessionRecorder(run: run, repository: repository);
    await run.startOrResume();
    await recorder.flush();
    expect(recorder.hasSaveError, isTrue);
    repository.failWrites = false;
    recorder.checkpoint();
    await recorder.flush();
    expect(recorder.hasSaveError, isFalse);
    recorder.dispose();
    run.dispose();
    await recorder.flush();
    final saved = (await repository.list(finished: false)).single;
    expect(saved.status, RunningStatus.paused);
    expect(await repository.list(finished: true), isEmpty);
    await source.controller.close();
  });
}
