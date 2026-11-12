import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'running_goal.dart';
import 'running_location.dart';
import 'running_measurement.dart';
import 'running_timer.dart';
import 'history/running_record.dart';

import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import '../route_recommendation/recommended_route.dart';
import '../../shared/widgets/running_map_data.dart';
import 'route_navigation.dart';

class RunningController extends ChangeNotifier {
  RunningController({
    required this.location,
    required this.timer,
    this.goal,
    RecommendedRoute? route,
    RunningMeasurement? measurement,
    DateTime Function()? now,
  }) : measurement = measurement ?? RunningMeasurement(),
       _now = now ?? DateTime.now {
    timer.prepare();
    if (route?.canRun == true) navigation = RouteNavigation(route!.coordinates);
    timer.addListener(_changed);
  }

  final RunningLocation location;
  final RunningTimer timer;
  RunningGoal? goal;
  final RunningMeasurement measurement;
  RouteNavigation? navigation;
  LatLng? currentPosition;
  List<List<LatLng>> trackSegments = const [];
  final DateTime Function() _now;
  GpsStatus gpsStatus = GpsStatus.connecting;
  bool preparing = false;
  bool hasStarted = false;
  DateTime? startedAt;
  bool _disposed = false;
  int _revision = 0;
  StreamSubscription<GpsPoint>? _subscription;
  Future<void> _cancellation = Future.value();
  Timer? _signalTimeout;
  Timer? _preparationTimeout;
  Completer<GpsStatus?>? _pendingPreparation;

  String get pace => measurement.pace(timer.elapsed);

  void restore(RunningRecord record) {
    if (timer.status != RunningStatus.ready || preparing || record.isFinished) {
      throw StateError('Only unfinished idle sessions can be recovered');
    }
    measurement.restore(
      meters: record.distanceMeters,
      points: record.points,
      segmentStarts: record.segmentStarts,
    );
    goal = record.goal;
    hasStarted = true;
    startedAt = record.startedAt;
    if (record.route?.canRun == true) {
      final passage = record.passage;
      navigation = RouteNavigation(
        record.route!.coordinates,
        settings: RouteNavigationSettings(cellMeters: passage?.cellMeters ?? 5),
        restored: passage,
      );
    } else {
      navigation = null;
    }
    trackSegments = gpsSegments(measurement.points, measurement.segmentStarts);
    // Historical coordinates are never presented as a live GPS fix.
    currentPosition = null;
    timer.restorePaused(record.activeTime);
    gpsStatus = GpsStatus.paused;
    _changed();
  }

  double get goalProgress => (switch (goal) {
    DistanceGoal(:final distanceKm) when distanceKm > 0 =>
      measurement.distanceMeters / (distanceKm * 1000),
    DurationGoal(:final duration) when duration > Duration.zero =>
      timer.elapsed.inMicroseconds / duration.inMicroseconds,
    _ => 0.0,
  }).clamp(0.0, 1.0);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startOrResume() async {
    if (_disposed ||
        preparing ||
        timer.status == RunningStatus.finished ||
        timer.status == RunningStatus.running) {
      return;
    }
    final revision = ++_revision;
    preparing = true;
    gpsStatus = GpsStatus.connecting;
    _changed();
    try {
      await _cancellation;
      if (_disposed || revision != _revision) return;
      final failure = await _prepareLocation();
      if (_disposed || revision != _revision) return;
      if (failure != null) {
        gpsStatus = failure;
        return;
      }
      measurement.breakSegment();
      hasStarted = true;
      startedAt ??= _now();
      if (timer.status == RunningStatus.ready) {
        timer.start();
      } else {
        timer.resume();
      }
      _watchSignal();
      _subscription = location.positions().listen(
        (point) {
          if (_disposed ||
              revision != _revision ||
              timer.status != RunningStatus.running) {
            return;
          }
          final age = _now().difference(point.timestamp);
          if (age > measurement.settings.maxGap ||
              age < const Duration(seconds: -5)) {
            gpsStatus = GpsStatus.weak;
            measurement.breakSegment();
            navigation?.breakSegment();
          } else {
            final count = measurement.pointCount;
            gpsStatus = measurement.add(point)
                ? GpsStatus.tracking
                : GpsStatus.weak;
            if (gpsStatus == GpsStatus.tracking) {
              currentPosition = LatLng(point.latitude, point.longitude);
              if (measurement.pointCount != count) {
                if (measurement.segmentStarts.lastOrNull == count) {
                  navigation?.breakSegment();
                }
                trackSegments = gpsSegments(
                  measurement.points,
                  measurement.segmentStarts,
                );
              }
              navigation?.add(point);
              _watchSignal();
            } else {
              navigation?.breakSegment();
            }
          }
          _changed();
        },
        onError: (Object error) {
          if (_disposed || revision != _revision) return;
          _signalTimeout?.cancel();
          measurement.breakSegment();
          navigation?.breakSegment();
          gpsStatus = switch (error) {
            LocationServiceDisabledException() => GpsStatus.serviceDisabled,
            PermissionDeniedException() => GpsStatus.denied,
            _ => GpsStatus.unavailable,
          };
          // A recoverable stream may emit another fix; pause/resume also retries.
          _changed();
        },
        onDone: () {
          if (_disposed || revision != _revision) return;
          _stopGps();
          if (gpsStatus != GpsStatus.serviceDisabled &&
              gpsStatus != GpsStatus.denied &&
              gpsStatus != GpsStatus.deniedForever) {
            gpsStatus = GpsStatus.unavailable;
          }
          timer.pause();
          _changed();
        },
      );
    } catch (error) {
      if (!_disposed && revision == _revision) {
        _stopGps();
        timer.pause();
        gpsStatus = switch (error) {
          LocationServiceDisabledException() => GpsStatus.serviceDisabled,
          PermissionDeniedException() => GpsStatus.denied,
          _ => GpsStatus.unavailable,
        };
      }
    } finally {
      if (!_disposed && revision == _revision) {
        preparing = false;
        _changed();
      }
    }
  }

  void _watchSignal() {
    _signalTimeout?.cancel();
    _signalTimeout = Timer(measurement.settings.maxGap, () {
      measurement.breakSegment();
      navigation?.breakSegment();
      gpsStatus = GpsStatus.weak;
      _changed();
    });
  }

  Future<GpsStatus?> _prepareLocation() async {
    final pending = Completer<GpsStatus?>();
    _pendingPreparation = pending;
    _preparationTimeout = Timer(const Duration(seconds: 30), () {
      if (!pending.isCompleted) {
        pending.completeError(TimeoutException('GPS permission check'));
      }
    });
    Future<GpsStatus?>.sync(location.prepare).then(
      (value) {
        if (!pending.isCompleted) pending.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!pending.isCompleted) pending.completeError(error, stack);
      },
    );
    try {
      return await pending.future;
    } finally {
      if (identical(_pendingPreparation, pending)) {
        _preparationTimeout?.cancel();
        _preparationTimeout = null;
        _pendingPreparation = null;
      }
    }
  }

  void _stopGps() {
    ++_revision;
    preparing = false;
    _preparationTimeout?.cancel();
    _preparationTimeout = null;
    final pending = _pendingPreparation;
    _pendingPreparation = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    _signalTimeout?.cancel();
    _signalTimeout = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      _cancellation = subscription.cancel().catchError((Object _) {});
    }
    measurement.breakSegment();
    navigation?.breakSegment();
  }

  void pause() {
    if (_disposed || timer.status == RunningStatus.finished) return;
    _stopGps();
    timer.pause();
    gpsStatus = GpsStatus.paused;
    _changed();
  }

  Future<void> finish() async {
    if (_disposed || timer.status == RunningStatus.finished) return;
    _stopGps();
    timer.finish();
    gpsStatus = GpsStatus.finished;
    _changed();
    await _cancellation;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopGps();
    timer.removeListener(_changed);
    timer.dispose();
    super.dispose();
  }
}
