import 'dart:math';

import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import '../../route_recommendation/recommended_route.dart';
import '../running_goal.dart';
import '../running_location.dart';
import '../running_timer.dart';
import '../route_navigation.dart';
import '../running_measurement.dart';

/// Immutable checkpoint. Recovered runs always wait paused for fresh GPS.
class RunningRecord {
  RunningRecord({
    required this.id,
    required this.startedAt,
    required this.updatedAt,
    required this.revision,
    required this.status,
    required this.activeTime,
    required this.distanceMeters,
    required Iterable<GpsPoint> points,
    required Iterable<int> segmentStarts,
    this.goal,
    this.route,
    this.passage,
  }) : points = List.unmodifiable(points),
       segmentStarts = List.unmodifiable(segmentStarts);

  final String id;
  final DateTime startedAt, updatedAt;
  final int revision;
  final RunningStatus status;
  final Duration activeTime;
  final double distanceMeters;
  final List<GpsPoint> points;
  final List<int> segmentStarts;
  final RunningGoal? goal;
  final RecommendedRoute? route;
  final RoutePassage? passage;
  bool get isFinished => status == RunningStatus.finished;
  double? get courseProgress => _navigation?.progress;
  bool? get courseCompleted => _navigation?.completed;
  RouteNavigation? get _navigation => route?.canRun == true && passage != null
      ? RouteNavigation(
          route!.coordinates,
          settings: RouteNavigationSettings(cellMeters: passage!.cellMeters),
          restored: passage,
        )
      : null;
  String get averagePace =>
      (RunningMeasurement()..distanceMeters = distanceMeters).pace(activeTime);

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    if (passage != null) 'navigation': passage!.toJson(),
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'status': status.name,
    'activeMicroseconds': activeTime.inMicroseconds,
    'distanceMeters': distanceMeters,
    'segmentStarts': segmentStarts,
    'points': [
      for (final p in points)
        {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracy': p.accuracy,
          'timestamp': p.timestamp.toUtc().toIso8601String(),
        },
    ],
    'goal': switch (goal) {
      DistanceGoal(:final distanceKm) => {'distanceKm': distanceKm},
      DurationGoal(:final duration) => {
        'microseconds': duration.inMicroseconds,
      },
      null => null,
    },
    if (route case final r?)
      'route': {
        'id': r.id,
        'name': r.name,
        'distanceKm': r.distanceKm,
        'source': r.source.name,
        'approachMeters': r.approachMeters,
        'durationMicroseconds': r.estimatedDuration.inMicroseconds,
        'coordinates': [
          for (final p in r.coordinates) [p.longitude, p.latitude],
        ],
      },
  };

  factory RunningRecord.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported run schema');
    }
    final goal = json['goal'] as Map?;
    final route = json['route'] as Map?;
    return RunningRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      revision: json['revision'] as int,
      status: RunningStatus.values.byName(json['status'] as String),
      activeTime: Duration(microseconds: json['activeMicroseconds'] as int),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      points: [
        for (final p in json['points'] as List)
          GpsPoint(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
            (p['accuracy'] as num).toDouble(),
            DateTime.parse(p['timestamp'] as String),
          ),
      ],
      segmentStarts: (json['segmentStarts'] as List).cast<int>(),
      goal: goal == null
          ? null
          : goal['distanceKm'] != null
          ? RunningGoal.distance((goal['distanceKm'] as num).toDouble())
          : RunningGoal.duration(
              Duration(microseconds: goal['microseconds'] as int),
            ),
      passage: RoutePassage.fromJson(json['navigation']),
      route: route == null
          ? null
          : RecommendedRoute(
              id: route['id'] as String,
              name: route['name'] as String,
              distanceKm: (route['distanceKm'] as num).toDouble(),
              estimatedDuration: Duration(
                microseconds: route['durationMicroseconds'] as int,
              ),
              source: RouteDataSource.values.byName(route['source'] as String),
              approachMeters: (route['approachMeters'] as num?)?.toDouble(),
              coordinates: [
                for (final p in route['coordinates'] as List)
                  LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
              ],
            ),
    );
  }
}
