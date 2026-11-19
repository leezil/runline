import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import '../route_drawing/drawing_controller.dart';

/// App domain types only: no server endpoint or JSON contract is assumed.
enum RouteDataSource { mock, api, synthetic }

class RouteGenerationInput {
  const RouteGenerationInput({
    required this.drawing,
    required this.minDistanceKm,
    required this.maxDistanceKm,
  }) : assert(minDistanceKm > 0),
       assert(maxDistanceKm >= minDistanceKm);

  final DrawingData drawing;
  final double minDistanceKm;
  final double maxDistanceKm;
}

class RecommendedRoute {
  RecommendedRoute({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.estimatedDuration,
    required Iterable<LatLng> coordinates,
    required this.source,
    this.approachMeters,
  }) : assert(distanceKm > 0),
       assert(estimatedDuration >= Duration.zero),
       coordinates = List.unmodifiable(coordinates);

  final String id;
  final String name;
  final double distanceKm;
  final Duration estimatedDuration;
  final List<LatLng> coordinates;
  final RouteDataSource source;
  final double? approachMeters;
  bool get isMock => source == RouteDataSource.mock;
  bool get canRun =>
      source == RouteDataSource.api &&
      distanceKm.isFinite &&
      distanceKm > 0 &&
      coordinates.length >= 2 &&
      coordinates.every(
        (p) =>
            p.latitude.isFinite &&
            p.longitude.isFinite &&
            p.latitude.abs() <= 90 &&
            p.longitude.abs() <= 180,
      );
}

/// Arbitrary drawing samples near Pangyo. Distances/times are illustrative,
/// unrelated to the drawing or distance request, and are not navigable routes.
final List<RecommendedRoute> mockRecommendedRoutes = List.unmodifiable([
  for (var i = 0; i < 3; i++)
    RecommendedRoute(
      id: 'mock-route-${i + 1}',
      name: '추천 ${i + 1}',
      distanceKm: 4.0 + i,
      estimatedDuration: Duration(minutes: 30 + i * 8),
      source: RouteDataSource.mock,
      coordinates: [
        const LatLng(37.4020, 127.1087),
        LatLng(37.4040 + i * .001, 127.1087),
        LatLng(37.4040 + i * .001, 127.1120 + i * .001),
        const LatLng(37.4020, 127.1120),
        const LatLng(37.4020, 127.1087),
      ],
    ),
]);
