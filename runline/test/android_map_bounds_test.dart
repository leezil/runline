import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/shared/widgets/runline_map_view_native.dart';

void main() {
  test('projects all four physical corners of a high-density map', () async {
    final calls = <(int, int)>[];
    final bounds = await androidMapBounds(const Size(320, 240), 2.625, (
      x,
      y,
    ) async {
      calls.add((x, y));
      // Rotated map: extrema can come from any of the four corners.
      return LatLng(37 + (x - y) / 100000, 127 + (x + y) / 100000);
    });
    expect(calls, [(0, 0), (839, 0), (0, 629), (839, 629)]);
    expect(bounds!.north, closeTo(37.00839, 1e-8));
    expect(bounds.south, closeTo(36.99371, 1e-8));
    expect(bounds.west, 127);
    expect(bounds.east, closeTo(127.01468, 1e-8));
  });
}
