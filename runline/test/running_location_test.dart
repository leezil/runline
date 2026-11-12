import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runline/features/running/running_controller.dart';
import 'package:runline/features/running/running_location.dart';
import 'package:runline/features/running/running_timer.dart';

import 'fake_running_location.dart';

void main() {
  group('production geolocator boundary', () {
    late GeolocatorPlatform original;
    late _LocationPlatform platform;
    setUp(() {
      original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = platform = _LocationPlatform();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });
    tearDown(() {
      GeolocatorPlatform.instance = original;
      debugDefaultTargetPlatformOverride = null;
    });
    test('service disabled never requests permission', () async {
      platform.enabled = false;
      expect(
        await GeolocatorRunningLocation().prepare(),
        GpsStatus.serviceDisabled,
      );
      expect(platform.requests, 0);
    });
    test(
      'request result distinguishes denied and permanently denied',
      () async {
        for (final permission in [
          LocationPermission.denied,
          LocationPermission.deniedForever,
        ]) {
          platform.requestedPermission = permission;
          expect(
            await GeolocatorRunningLocation().prepare(),
            permission == LocationPermission.denied
                ? GpsStatus.denied
                : GpsStatus.deniedForever,
          );
        }
        expect(platform.requests, 2);
      },
    );
    test('permanent denial is not requested again', () async {
      platform.permission = LocationPermission.deniedForever;
      expect(
        await GeolocatorRunningLocation().prepare(),
        GpsStatus.deniedForever,
      );
      expect(platform.requests, 0);
    });
    test(
      'foreground grant permits GPS without requesting background permission',
      () async {
        expect(await GeolocatorRunningLocation().prepare(), isNull);
        expect(platform.requests, 1);
        platform.permission = LocationPermission.whileInUse;
        expect(await GeolocatorRunningLocation().prepare(), isNull);
        expect(platform.requests, 1);
      },
    );
  });

  testWidgets(
    'pending preparation is canceled on dispose and late grant is ignored',
    (tester) async {
      final pending = Completer<GpsStatus?>();
      final source = _DelayedLocation(pending.future);
      final run = RunningController(location: source, timer: RunningTimer());
      final start = run.startOrResume();
      await tester.pump();
      run.dispose();
      await tester.pump(const Duration(seconds: 31));
      await start;
      pending.complete(null);
      await tester.pump();
      expect(source.subscriptions, 0);
    },
  );

  testWidgets(
    'permission check timeout remains retryable and does not start timer',
    (tester) async {
      final pending = Completer<GpsStatus?>();
      final source = _DelayedLocation(pending.future);
      final run = RunningController(location: source, timer: RunningTimer());
      final start = run.startOrResume();
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      await start;
      expect(run.gpsStatus, GpsStatus.unavailable);
      expect(run.timer.status, RunningStatus.ready);
      expect(run.preparing, isFalse);
      run.dispose();
      pending.complete(null);
      await tester.pump();
    },
  );

  testWidgets(
    'service error stays visible; recovery and stale fixes never bridge outage',
    (tester) async {
      final source = FakeRunningLocation();
      var now = DateTime.utc(2026, 1, 1);
      final run = RunningController(
        location: source,
        timer: RunningTimer(),
        now: () => now,
      );
      await run.startOrResume();
      source.controller.add(GpsPoint(0, 0, 3, now));
      source.controller.addError(const LocationServiceDisabledException());
      await tester.pump(const Duration(seconds: 16));
      expect(run.gpsStatus, GpsStatus.serviceDisabled);
      now = now.add(const Duration(minutes: 1));
      source.controller.add(
        GpsPoint(1, 1, 3, now.subtract(const Duration(minutes: 1))),
      );
      expect(run.gpsStatus, GpsStatus.weak);
      source.controller.add(GpsPoint(1, 1, 3, now));
      expect(run.gpsStatus, GpsStatus.tracking);
      expect(run.measurement.distanceMeters, 0);
      run.dispose();
      await source.controller.close();
    },
  );

  testWidgets('terminal stream preserves the service-disabled explanation', (
    tester,
  ) async {
    final source = FakeRunningLocation();
    final run = RunningController(location: source, timer: RunningTimer());
    await run.startOrResume();
    source.controller.addError(const LocationServiceDisabledException());
    await source.controller.close();
    expect(run.gpsStatus, GpsStatus.serviceDisabled);
    expect(run.timer.status, RunningStatus.paused);
    run.dispose();
    await tester.pump();
  });
}

class _LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }
}

class _DelayedLocation implements RunningLocation {
  _DelayedLocation(this.future);
  final Future<GpsStatus?> future;
  int subscriptions = 0;
  @override
  Future<GpsStatus?> prepare() => future;
  @override
  Stream<GpsPoint> positions() {
    subscriptions++;
    return const Stream.empty();
  }
}
