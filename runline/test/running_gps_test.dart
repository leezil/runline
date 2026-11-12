import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/running/running_controller.dart';
import 'package:runline/features/running/running_goal.dart';
import 'package:runline/features/running/running_location.dart';
import 'package:runline/features/running/running_measurement.dart';
import 'package:runline/features/running/running_timer.dart';

import 'fake_running_location.dart';

void main() {
  final epoch = DateTime.utc(2026, 1, 1);
  GpsPoint point(double northMeters, int seconds, {double accuracy = 3}) =>
      GpsPoint(
        northMeters / 111194.9266,
        0,
        accuracy,
        epoch.add(Duration(seconds: seconds)),
      );

  for (final failure in [
    GpsStatus.denied,
    GpsStatus.deniedForever,
    GpsStatus.serviceDisabled,
    GpsStatus.unavailable,
  ]) {
    test('$failure prevents timer and stream start; retry succeeds', () async {
      final source = FakeRunningLocation()..failure = failure;
      final run = RunningController(location: source, timer: RunningTimer());
      addTearDown(run.dispose);
      addTearDown(source.controller.close);
      await run.startOrResume();
      expect(run.gpsStatus, failure);
      expect(run.timer.status, RunningStatus.ready);
      expect(source.subscriptions, 0);
      source.failure = null;
      await run.startOrResume();
      expect(run.timer.status, RunningStatus.running);
      expect(run.gpsStatus, GpsStatus.connecting);
    });
  }

  test('surface distance, accuracy, jumps, jitter and chronology filters', () {
    final m = RunningMeasurement();
    expect(m.distanceMeters, 0);
    expect(m.add(point(0, 0)), isTrue);
    for (var s = 1; s < 8; s++) {
      m.add(point(s.isEven ? 2 : -2, s));
    }
    expect(m.distanceMeters, 0);
    expect(m.add(point(20, 8)), isTrue);
    expect(m.distanceMeters, closeTo(20, 0.01));
    expect(m.add(point(1000, 9)), isFalse);
    expect(m.add(point(30, 10)), isTrue);
    expect(m.distanceMeters, closeTo(30, 0.01));
    expect(m.add(point(35, 9)), isFalse);
    expect(m.add(point(100, 11, accuracy: 100)), isFalse);
    m.add(point(110, 12)); // reacquisition never bridges poor fixes
    expect(m.distanceMeters, closeTo(30, 0.01));
    m.add(point(120, 40)); // long outage starts a new segment
    expect(m.distanceMeters, closeTo(30, 0.01));
    expect(
      m.points.map((p) => p.timestamp),
      orderedEquals([
        epoch,
        epoch.add(const Duration(seconds: 8)),
        epoch.add(const Duration(seconds: 10)),
        epoch.add(const Duration(seconds: 12)),
        epoch.add(const Duration(seconds: 40)),
      ]),
    );
  });

  test('pace needs distance and active time; formats rounded seconds', () {
    final m = RunningMeasurement();
    expect(m.pace(const Duration(minutes: 1)), "--'--\"");
    m.add(point(0, 0));
    m.add(point(10, 2));
    expect(m.pace(const Duration(seconds: 3)), "--'--\"");
    m.add(point(30, 5));
    expect(m.pace(Duration.zero), "--'--\"");
    expect(m.pace(const Duration(seconds: 9)), "05'00\"");
  });

  test(
    'pause/resume segments, goals, frozen result and stream cleanup',
    () async {
      var elapsed = Duration.zero;
      final source = FakeRunningLocation();
      final run = RunningController(
        location: source,
        timer: RunningTimer(now: () => elapsed),
        now: () => epoch.add(elapsed),
        goal: const RunningGoal.distance(0.05),
      );
      addTearDown(run.dispose);
      addTearDown(source.controller.close);
      await run.startOrResume();
      await run.startOrResume();
      expect(source.subscriptions, 1);
      source.controller.add(point(0, 0));
      elapsed = const Duration(seconds: 5);
      source.controller.add(point(25, 5));
      expect(run.goalProgress, closeTo(0.5, 0.001));
      run.pause();
      elapsed = const Duration(seconds: 10);
      source.controller.add(point(500, 10));
      expect(run.measurement.distanceMeters, closeTo(25, 0.01));
      expect(run.timer.elapsed, const Duration(seconds: 5));
      await run.startOrResume();
      source.controller.add(point(500, 10));
      elapsed = const Duration(seconds: 15);
      source.controller.add(point(525, 15));
      expect(run.measurement.distanceMeters, closeTo(50, 0.01));
      expect(run.goalProgress, closeTo(1, 0.001));
      expect(run.timer.status, RunningStatus.running);
      await run.finish();
      final pace = run.pace;
      elapsed = const Duration(hours: 1);
      source.controller.add(point(550, 20));
      await run.finish();
      expect(run.timer.elapsed, const Duration(seconds: 10));
      expect(run.pace, pace);
      expect(source.cancellations, 2);
      expect(source.controller.hasListener, isFalse);
    },
  );

  testWidgets('signal timeout, stream errors and disposal are safe', (
    tester,
  ) async {
    final source = FakeRunningLocation();
    final run = RunningController(
      location: source,
      timer: RunningTimer(),
      now: () => epoch,
    );
    await run.startOrResume();
    source.controller.add(point(0, 0));
    expect(run.gpsStatus, GpsStatus.tracking);
    await tester.pump(const Duration(seconds: 16));
    expect(run.gpsStatus, GpsStatus.weak);
    source.controller.addError(StateError('offline'));
    expect(run.gpsStatus, GpsStatus.unavailable);
    run.dispose();
    await tester.pump();
    expect(source.controller.hasListener, isFalse);
    await source.controller.close();
  });

  test(
    'finish during permission request cannot start a late subscription',
    () async {
      final pending = Completer<GpsStatus?>();
      final run = RunningController(
        location: _PendingLocation(pending.future),
        timer: RunningTimer(),
      );
      addTearDown(run.dispose);
      final start = run.startOrResume();
      await run.finish();
      pending.complete(null);
      await start;
      expect(run.timer.status, RunningStatus.finished);
      expect(run.gpsStatus, GpsStatus.finished);
    },
  );

  test(
    'duration goal excludes pauses without automatically finishing',
    () async {
      var now = Duration.zero;
      final source = FakeRunningLocation();
      final run = RunningController(
        location: source,
        timer: RunningTimer(now: () => now),
        goal: const RunningGoal.duration(Duration(minutes: 1)),
      );
      addTearDown(run.dispose);
      addTearDown(source.controller.close);
      await run.startOrResume();
      now = const Duration(seconds: 30);
      run.pause();
      now = const Duration(minutes: 3);
      expect(run.goalProgress, 0.5);
      await run.startOrResume();
      now += const Duration(seconds: 40);
      expect(run.goalProgress, 1);
      expect(run.timer.status, RunningStatus.running);
    },
  );
}

class _PendingLocation implements RunningLocation {
  _PendingLocation(this.pending);
  final Future<GpsStatus?> pending;
  @override
  Future<GpsStatus?> prepare() => pending;
  @override
  Stream<GpsPoint> positions() => throw StateError('must not subscribe');
}
