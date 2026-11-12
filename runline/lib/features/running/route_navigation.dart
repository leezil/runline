import 'dart:math' as math;

import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import 'running_location.dart';
import 'running_measurement.dart';

/// Completion tolerance and deviation hysteresis are deliberately independent.
class RouteNavigationSettings {
  const RouteNavigationSettings({
    this.cellMeters = 5,
    this.passageToleranceMeters = 10,
    this.maxPassageAccuracyMeters = 12,
    this.offRouteMeters = 30,
    this.rejoinMeters = 18,
    this.offRouteFixes = 3,
    this.startWindowMeters = 15,
    this.forwardWindowMeters = 35,
    this.backtrackMeters = 12,
    this.maxGap = const Duration(seconds: 15),
  });
  final double cellMeters, passageToleranceMeters, maxPassageAccuracyMeters;
  final double offRouteMeters, rejoinMeters;
  final int offRouteFixes;
  final double startWindowMeters, forwardWindowMeters, backtrackMeters;
  final Duration maxGap;
}

/// Optional extension to schema 1. Old records have no passage evidence.
class RoutePassage {
  RoutePassage({
    required this.cellMeters,
    required this.totalMeters,
    required this.cursorMeters,
    required Iterable<int> coveredCells,
    Iterable<List<double>> coveredRanges = const [],
  }) : coveredCells = List.unmodifiable(coveredCells),
       coveredRanges = List.unmodifiable(
         coveredRanges.map((e) => List<double>.unmodifiable(e)),
       );
  final double cellMeters, totalMeters, cursorMeters;
  final List<int> coveredCells;
  final List<List<double>> coveredRanges;
  Map<String, Object?> toJson() => {
    'version': 1,
    'cellMeters': cellMeters,
    'totalMeters': totalMeters,
    'cursorMeters': cursorMeters,
    'coveredCells': coveredCells,
    'coveredRanges': coveredRanges,
  };
  static RoutePassage? fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) return null;
    final cell = value['cellMeters'], total = value['totalMeters'];
    final cursor = value['cursorMeters'], cells = value['coveredCells'];
    if (cell is! num ||
        !cell.isFinite ||
        cell < 1 ||
        cell > 20 ||
        total is! num ||
        !total.isFinite ||
        total <= 0 ||
        cursor is! num ||
        !cursor.isFinite ||
        cursor < 0 ||
        cursor > total ||
        cells is! List ||
        cells.any((e) => e is! int || e < 0)) {
      return null;
    }
    final ranges = value['coveredRanges'];
    if (ranges != null &&
        (ranges is! List ||
            ranges.any(
              (r) =>
                  r is! List ||
                  r.length != 2 ||
                  r.any((v) => v is! num || !v.isFinite) ||
                  r[0] < 0 ||
                  r[1] <= r[0] ||
                  r[1] > total,
            ))) {
      return null;
    }
    return RoutePassage(
      cellMeters: cell.toDouble(),
      totalMeters: total.toDouble(),
      cursorMeters: cursor.toDouble(),
      coveredCells: cells.cast<int>(),
      coveredRanges: ranges == null
          ? const []
          : (ranges as List).map(
              (r) => [(r[0] as num).toDouble(), (r[1] as num).toDouble()],
            ),
    );
  }
}

class _Projection {
  const _Projection(this.along, this.distance);
  final double along, distance;
}

/// Ordered, bounded map matching. Never converts free-running distance to route
/// completion. A cell needs two continuous, accurate GPS fixes whose chord
/// follows that cell. Crossing/overlapping later occurrences stay uncredited.
class RouteNavigation {
  RouteNavigation(
    List<LatLng> coordinates, {
    this.settings = const RouteNavigationSettings(),
    RoutePassage? restored,
  }) {
    assert(settings.cellMeters > 0);
    if (coordinates.length < 2) return;
    samples.add(coordinates.first);
    distances.add(0);
    for (var i = 1; i < coordinates.length; i++) {
      final a = coordinates[i - 1], b = coordinates[i];
      final meters = distance(a, b);
      if (meters < .01) continue;
      final count = (meters / settings.cellMeters).ceil();
      for (var j = 1; j <= count; j++) {
        samples.add(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * j / count,
            a.longitude + (b.longitude - a.longitude) * j / count,
          ),
        );
        distances.add(distances.last + meters / count);
      }
    }
    if (restored != null &&
        (restored.totalMeters - totalMeters).abs() < .1 &&
        (restored.cellMeters - settings.cellMeters).abs() < .01) {
      _covered.addAll(
        restored.coveredCells.where((i) => i < samples.length - 1),
      );
      if (restored.coveredRanges.isNotEmpty) {
        for (final r in restored.coveredRanges) {
          _cover(r[0], r[1]);
        }
      } else {
        for (final i in _covered) {
          _cover(distances[i], distances[i + 1]);
        }
      }
      cursorMeters = restored.cursorMeters.clamp(0, totalMeters);
      _started = cursorMeters > 0 || _covered.isNotEmpty;
    }
    _rebuildCompleted();
  }
  final RouteNavigationSettings settings;
  final List<LatLng> samples = [];
  final List<double> distances = [];
  final Set<int> _covered = {};
  final List<List<double>> _ranges = [];
  GpsPoint? _previous;
  double? _previousAlong;
  bool _started = false;
  GpsPoint? _rejoinFix;
  double? _rejoinAlong;
  int _rejoinCount = 0;
  int _outsideFixes = 0;
  bool offRoute = false;
  bool passageReliable = false;
  double? distanceFromRoute;
  double cursorMeters = 0;
  double? matchedMeters;
  List<List<LatLng>> completedSegments = const [];
  List<List<LatLng>> unpassedSegments = const [];
  List<LatLng> directionCoordinates = const [];
  double get totalMeters => distances.lastOrNull ?? 0;
  double get passedMeters => _ranges.fold(0, (sum, r) => sum + r[1] - r[0]);
  double get remainingMeters => math.max(0, totalMeters - passedMeters);
  double get progress =>
      totalMeters > 0 ? (passedMeters / totalMeters).clamp(0, 1) : 0;
  bool get completed =>
      totalMeters > 0 &&
      _ranges.length == 1 &&
      _ranges.first[0] <= .25 &&
      _ranges.first[1] >= totalMeters - .25;
  RoutePassage get snapshot => RoutePassage(
    cellMeters: settings.cellMeters,
    totalMeters: totalMeters,
    cursorMeters: cursorMeters,
    coveredCells: _covered.toList()..sort(),
    coveredRanges: _ranges,
  );

  void breakSegment() {
    passageReliable = false;
    _previous = null;
    _previousAlong = null;
    _rejoinFix = null;
    _rejoinAlong = null;
    _rejoinCount = 0;
  }

  void add(GpsPoint point) {
    if (samples.length < 2) return;
    // Poor fixes neither complete cells nor trigger a spurious deviation alert.
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        !point.accuracy.isFinite ||
        point.accuracy < 0 ||
        point.accuracy > settings.maxPassageAccuracyMeters) {
      breakSegment();
      return;
    }
    passageReliable = true;
    final position = LatLng(point.latitude, point.longitude);
    var nearest = double.infinity;
    _Projection? match;
    final projections = <_Projection>[];
    var score = double.infinity;
    final previous = _previous;
    final movement = previous == null
        ? 0.0
        : distance(position, LatLng(previous.latitude, previous.longitude));
    final expected = (_previousAlong ?? cursorMeters) + movement;
    final upper = _started
        ? cursorMeters + settings.forwardWindowMeters
        : settings.startWindowMeters;
    for (var i = 0; i < samples.length - 1; i++) {
      final projection = _project(
        position,
        samples[i],
        samples[i + 1],
        distances[i],
        distances[i + 1] - distances[i],
      );
      projections.add(projection);
      nearest = math.min(nearest, projection.distance);
      if (projection.along < cursorMeters - settings.backtrackMeters ||
          projection.along > upper) {
        continue;
      }
      // Distance first; continuity breaks geometric ties at crossings/repeats.
      final candidateScore =
          projection.distance + (projection.along - expected).abs() * .15;
      if (candidateScore < score) {
        score = candidateScore;
        match = projection;
      }
    }
    distanceFromRoute = nearest;
    if (nearest > settings.offRouteMeters) {
      if (++_outsideFixes >= settings.offRouteFixes) offRoute = true;
    } else if (nearest < settings.rejoinMeters) {
      _outsideFixes = 0;
      offRoute = false;
    } else {
      _outsideFixes = 0;
    }
    if (match == null || match.distance > settings.passageToleranceMeters) {
      // A distant rejoin needs three ordered, unambiguous moving fixes. It
      // relocates the cursor only: the skipped route receives NO coverage.
      if (_started && _tryRejoin(point, projections)) return;
      _previous = null;
      _previousAlong = null;
      matchedMeters = null;
      directionCoordinates = const [];
      return;
    }
    _rejoinFix = null;
    _rejoinAlong = null;
    _rejoinCount = 0;
    if (!_started) {
      // Require the beginning of the course, not an arbitrary crossing near it.
      if (match.along > 3) {
        breakSegment();
        return;
      }
      _started = true;
    }
    final seconds = previous == null
        ? 0.0
        : point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (previous != null && seconds <= 0) return;
    if (previous != null &&
        movement < 3 &&
        seconds <= settings.maxGap.inMilliseconds / 1000) {
      return;
    }
    final from = _previousAlong;
    if (previous != null &&
        from != null &&
        seconds > 0 &&
        seconds <= settings.maxGap.inMilliseconds / 1000 &&
        movement >= 3 &&
        movement / seconds <= 10 &&
        match.along > from &&
        match.along - from <= movement * 1.35 + 2) {
      final oldPosition = LatLng(previous.latitude, previous.longitude);
      // Both endpoints AND midpoint of each route cell must be near the GPS
      // chord. This does not fill a detour, bend, or an unobserved pause gap.
      for (var i = 0; i < samples.length - 1; i++) {
        final start = math.max(distances[i], from),
            end = math.min(distances[i + 1], match.along);
        if (end <= start) continue;
        final a = pointAt(start), b = pointAt(end);
        final mid = LatLng(
          (a.latitude + b.latitude) / 2,
          (a.longitude + b.longitude) / 2,
        );
        if ([a, mid, b].every(
          (p) =>
              _project(p, oldPosition, position, 0, movement).distance <=
              settings.passageToleranceMeters,
        )) {
          _cover(start, end);
        }
      }
    }
    matchedMeters = match.along;
    cursorMeters = math.max(cursorMeters, match.along);
    _previous = point;
    _previousAlong = match.along;
    _rebuildCompleted();
    _updateDirection();
  }

  bool _tryRejoin(GpsPoint point, List<_Projection> projections) {
    final candidates =
        projections
            .where(
              (p) =>
                  p.along > cursorMeters + settings.forwardWindowMeters &&
                  p.distance <= settings.passageToleranceMeters,
            )
            .toList()
          ..sort((a, b) => a.distance.compareTo(b.distance));
    if (candidates.isEmpty) {
      _rejoinFix = null;
      _rejoinCount = 0;
      return false;
    }
    final best = candidates.first;
    // Exact repeated geometry and crossings cannot identify the occurrence.
    if (projections.any(
      (p) =>
          (p.along - best.along).abs() > 20 &&
          p.distance <= best.distance + point.accuracy,
    )) {
      _rejoinFix = null;
      _rejoinCount = 0;
      return false;
    }
    final previous = _rejoinFix;
    final along = _rejoinAlong;
    final seconds = previous == null
        ? 0.0
        : point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    final moved = previous == null
        ? 0.0
        : distance(
            LatLng(previous.latitude, previous.longitude),
            LatLng(point.latitude, point.longitude),
          );
    if (previous != null &&
        along != null &&
        seconds > 0 &&
        seconds <= settings.maxGap.inMilliseconds / 1000 &&
        moved >= 3 &&
        moved / seconds <= 10 &&
        best.along > along &&
        best.along - along <= moved * 1.35 + 2) {
      _rejoinCount++;
    } else {
      _rejoinCount = 1;
    }
    _rejoinFix = point;
    _rejoinAlong = best.along;
    if (_rejoinCount < 3) return false;
    cursorMeters = best.along;
    matchedMeters = best.along;
    _previous = point;
    _previousAlong = best.along;
    _rejoinFix = null;
    _rejoinAlong = null;
    _rejoinCount = 0;
    _updateDirection();
    return true;
  }

  void _rebuildCompleted() {
    final result = <List<LatLng>>[];
    for (final range in _ranges) {
      result.add([
        pointAt(range[0]),
        for (var i = 1; i < samples.length; i++)
          if (distances[i] > range[0] && distances[i] < range[1]) samples[i],
        pointAt(range[1]),
      ]);
    }
    completedSegments = List.unmodifiable(
      result.map((e) => List<LatLng>.unmodifiable(e)),
    );
    final pending = <List<LatLng>>[];
    double cursor = 0;
    void append(double start, double end) {
      if (end - start < .01) return;
      pending.add([
        pointAt(start),
        for (var i = 1; i < samples.length; i++)
          if (distances[i] > start && distances[i] < end) samples[i],
        pointAt(end),
      ]);
    }

    for (final range in _ranges) {
      append(cursor, range[0]);
      cursor = range[1];
    }
    append(cursor, totalMeters);
    unpassedSegments = List.unmodifiable(
      pending.map((e) => List<LatLng>.unmodifiable(e)),
    );
  }

  void _cover(double from, double to) {
    if (to <= from) return;
    final combined = <List<double>>[
      ..._ranges,
      [from, to],
    ]..sort((a, b) => a[0].compareTo(b[0]));
    _ranges.clear();
    for (final r in combined) {
      if (_ranges.isNotEmpty && r[0] <= _ranges.last[1] + .01) {
        _ranges.last[1] = math.max(_ranges.last[1], r[1]);
      } else {
        _ranges.add(List.of(r));
      }
    }
  }

  LatLng pointAt(double along) {
    if (samples.isEmpty) return const LatLng(0, 0);
    for (var i = 1; i < distances.length; i++) {
      if (distances[i] >= along) {
        final t =
            ((along - distances[i - 1]) / (distances[i] - distances[i - 1]))
                .clamp(0.0, 1.0);
        return LatLng(
          samples[i - 1].latitude +
              (samples[i].latitude - samples[i - 1].latitude) * t,
          samples[i - 1].longitude +
              (samples[i].longitude - samples[i - 1].longitude) * t,
        );
      }
    }
    return samples.last;
  }

  void _updateDirection() {
    if (offRoute || completed || cursorMeters >= totalMeters) {
      directionCoordinates = const [];
      return;
    }
    final start = matchedMeters ?? cursorMeters;
    final end = math.min(totalMeters, start + 15);
    final from = pointAt(start), tip = pointAt(end);
    final tangent = pointAt(math.max(start, end - 3));
    final dx =
        (tip.longitude - tangent.longitude) *
        math.cos(tip.latitude * math.pi / 180);
    final dy = tip.latitude - tangent.latitude;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-10) {
      directionCoordinates = const [];
      return;
    }
    final ux = dx / len, uy = dy / len;
    const wing = 5 / 111195.0;
    LatLng side(double sign) => LatLng(
      tip.latitude - uy * wing + sign * ux * wing * .6,
      tip.longitude +
          (-ux * wing - sign * uy * wing * .6) /
              math.cos(tip.latitude * math.pi / 180),
    );
    directionCoordinates = List.unmodifiable([
      from,
      for (var i = 1; i < samples.length; i++)
        if (distances[i] > start && distances[i] < end) samples[i],
      tip,
      side(1),
      tip,
      side(-1),
    ]);
  }

  static double distance(LatLng a, LatLng b) =>
      RunningMeasurement.surfaceDistance(
        GpsPoint(a.latitude, a.longitude, 0, DateTime.utc(2000)),
        GpsPoint(b.latitude, b.longitude, 0, DateTime.utc(2000)),
      );

  static _Projection _project(
    LatLng p,
    LatLng a,
    LatLng b,
    double base,
    double length,
  ) {
    final cos = math.cos(p.latitude * math.pi / 180);
    final ax = (a.longitude - p.longitude) * 111195 * cos;
    final ay = (a.latitude - p.latitude) * 111195;
    final bx = (b.longitude - p.longitude) * 111195 * cos;
    final by = (b.latitude - p.latitude) * 111195;
    final dx = bx - ax, dy = by - ay, square = dx * dx + dy * dy;
    final t = square == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / square).clamp(0.0, 1.0);
    return _Projection(
      base + length * t,
      math.sqrt(math.pow(ax + dx * t, 2) + math.pow(ay + dy * t, 2)),
    );
  }
}
