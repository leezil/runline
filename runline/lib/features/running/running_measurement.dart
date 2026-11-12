import 'dart:math' as math;

import 'running_location.dart';

/// Foreground running defaults; tune using real-device walk/run recordings.
class GpsFilterSettings {
  const GpsFilterSettings({
    this.maxAccuracyMeters = 25,
    this.minMovementMeters = 5,
    this.accuracyMovementFactor = 0.5,
    this.maxSpeedMetersPerSecond = 10,
    this.maxGap = const Duration(seconds: 15),
    this.minimumPaceDistanceMeters = 20,
  });
  final double maxAccuracyMeters;
  final double minMovementMeters;
  final double accuracyMovementFactor;
  final double maxSpeedMetersPerSecond;
  final Duration maxGap;
  final double minimumPaceDistanceMeters;
}

class RunningMeasurement {
  RunningMeasurement({this.settings = const GpsFilterSettings()});
  final GpsFilterSettings settings;
  final List<GpsPoint> _points = [];
  List<GpsPoint> get points => List.unmodifiable(_points);
  int get pointCount => _points.length;
  final List<int> _segmentStarts = [];
  List<int> get segmentStarts => List.unmodifiable(_segmentStarts);
  GpsPoint? _anchor;
  DateTime? _lastTimestamp;
  double distanceMeters = 0;

  void breakSegment() => _anchor = null;

  /// Returns false for unusable fixes. Small movements are valid fixes but
  /// don't replace the anchor, allowing genuine slow movement to accumulate.
  bool add(GpsPoint point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        !point.accuracy.isFinite ||
        point.accuracy < 0 ||
        (_lastTimestamp != null && !point.timestamp.isAfter(_lastTimestamp!))) {
      return false;
    }
    _lastTimestamp = point.timestamp;
    if (point.accuracy > settings.maxAccuracyMeters) {
      breakSegment();
      return false;
    }
    final previous = _anchor;
    if (previous == null) {
      _anchor = point;
      _segmentStarts.add(_points.length);
      _points.add(point);
      return true;
    }
    final seconds =
        point.timestamp.difference(previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (seconds >
        settings.maxGap.inMicroseconds / Duration.microsecondsPerSecond) {
      _anchor = point;
      _segmentStarts.add(_points.length);
      _points.add(point);
      return true;
    }
    final distance = surfaceDistance(previous, point);
    if (distance / seconds > settings.maxSpeedMetersPerSecond) {
      return false;
    }
    final threshold = math.max(
      settings.minMovementMeters,
      math.max(previous.accuracy, point.accuracy) *
          settings.accuracyMovementFactor,
    );
    if (distance >= threshold) {
      distanceMeters += distance;
      _anchor = point;
      _points.add(point);
    }
    return true;
  }

  void restore({
    required double meters,
    required List<GpsPoint> points,
    required List<int> segmentStarts,
  }) {
    if (_points.isNotEmpty ||
        distanceMeters != 0 ||
        !meters.isFinite ||
        meters < 0) {
      throw StateError('Invalid measurement recovery');
    }
    distanceMeters = meters;
    _points.addAll(points);
    _segmentStarts.addAll(segmentStarts);
    _lastTimestamp = points.lastOrNull?.timestamp;
    breakSegment();
  }

  String pace(Duration activeTime) {
    if (distanceMeters < settings.minimumPaceDistanceMeters ||
        distanceMeters <= 0 ||
        activeTime <= Duration.zero) {
      return "--'--\"";
    }
    final seconds = (activeTime.inMilliseconds / distanceMeters).round();
    return "${(seconds ~/ 60).toString().padLeft(2, '0')}'${(seconds % 60).toString().padLeft(2, '0')}\"";
  }

  /// Haversine great-circle distance in meters (mean Earth radius).
  static double surfaceDistance(GpsPoint a, GpsPoint b) {
    const radians = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * radians;
    final dLon = (b.longitude - a.longitude) * radians;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * radians) *
            math.cos(b.latitude * radians) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }
}
