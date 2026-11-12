import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import '../../features/running/running_location.dart';

const routeBlue = Color(0xFF3D5AFE);
const passageGreen = Color(0xFF16854A);
const actualPurple = Color(0xFF9C27B0);
const directionAmber = Color(0xFFF59E0B);

/// Never connect endpoints on opposite sides of a pause or signal outage.
List<List<LatLng>> gpsSegments(List<GpsPoint> points, List<int> starts) {
  final boundaries = starts.toSet()..add(0);
  final result = <List<LatLng>>[];
  for (var i = 0; i < points.length; i++) {
    if (boundaries.contains(i)) result.add(<LatLng>[]);
    result.last.add(LatLng(points[i].latitude, points[i].longitude));
  }
  return List.unmodifiable(result.map((e) => List<LatLng>.unmodifiable(e)));
}

class RunningMapLine {
  const RunningMapLine(this.points, this.color, this.width);
  final List<LatLng> points;
  final Color color;
  final double width;
}

List<RunningMapLine> runningMapLines({
  required List<LatLng> route,
  List<List<LatLng>>? remaining,
  required List<List<LatLng>> tracks,
  required List<List<LatLng>> passed,
  required List<LatLng> direction,
  required bool routeRun,
}) => [
  for (final track in tracks)
    if (track.length > 1)
      RunningMapLine(
        track,
        routeRun ? actualPurple : passageGreen,
        routeRun ? 4 : 5,
      ),
  if (remaining == null && route.length > 1)
    RunningMapLine(route, routeBlue, 9),
  if (remaining != null)
    for (final part in remaining)
      if (part.length > 1) RunningMapLine(part, routeBlue, 9),
  for (final part in passed)
    if (part.length > 1) RunningMapLine(part, passageGreen, 5),
  if (direction.length > 1) RunningMapLine(direction, directionAmber, 5),
];
