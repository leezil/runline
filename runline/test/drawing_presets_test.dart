import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/route_drawing/drawing_controller.dart';
import 'package:runline/features/route_drawing/drawing_presets.dart';
import 'package:runline/features/route_generation/route_api.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';

void main() {
  for (final preset in DrawingPreset.values) {
    test(
      '${preset.name} has one simple, ordered closed outline in unit coordinates',
      () {
        final points = preset.normalizedPoints;
        expect(points.length, inInclusiveRange(3, 3000));
        expect(points.first, points.last);
        expect(
          points.take(points.length - 1).toSet().length,
          points.length - 1,
        );
        for (var i = 0; i < points.length; i++) {
          expect(points[i].dx, inInclusiveRange(0, 1));
          expect(points[i].dy, inInclusiveRange(0, 1));
          if (i > 0) {
            expect((points[i] - points[i - 1]).distance, greaterThan(1e-9));
          }
        }
        // A crossing would turn an outline into an unintended road-search target.
        double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
        for (var i = 0; i < points.length - 1; i++) {
          for (var j = i + 2; j < points.length - 1; j++) {
            if (i == 0 && j == points.length - 2) continue;
            final a = points[i],
                b = points[i + 1],
                c = points[j],
                d = points[j + 1];
            final crosses =
                cross(b - a, c - a) * cross(b - a, d - a) < -1e-12 &&
                cross(d - c, a - c) * cross(d - c, b - c) < -1e-12;
            expect(crosses, isFalse, reason: 'Edges $i and $j must not cross');
          }
        }
        if (preset == DrawingPreset.star) expect(points.length, 11);
        if (preset == DrawingPreset.crescent) {
          final gaps = [
            for (var i = 1; i < points.length; i++)
              (points[i] - points[i - 1]).distance,
          ];
          expect(gaps.reduce(math.max), lessThan(.05));
        }
      },
    );

    test(
      '${preset.name} keeps proportions and margins across canvas sizes',
      () {
        const sizes = [Size(300, 300), Size(900, 240), Size(240, 900)];
        final normalized = preset.normalizedPoints;
        for (final size in sizes) {
          final points = preset.pointsFor(size);
          final side = size.shortestSide * .85;
          for (var i = 0; i < points.length; i++) {
            expect(points[i].dx, inInclusiveRange(0, size.width));
            expect(points[i].dy, inInclusiveRange(0, size.height));
            expect(
              (points[i].dx - size.width / 2) / side,
              closeTo(normalized[i].dx - .5, 1e-10),
            );
            expect(
              (points[i].dy - size.height / 2) / side,
              closeTo(normalized[i].dy - .5, 1e-10),
            );
          }
        }
        expect(() => preset.pointsFor(Size.zero), throwsArgumentError);
      },
    );

    test(
      '${preset.name} uses existing POST contract and filters server candidates',
      () async {
        final drawing = DrawingController()
          ..updateViewport(const Size(600, 300))
          ..selectPreset(preset);
        addTearDown(drawing.dispose);
        final snapshot = drawing.snapshot()!;
        final api = RouteApi(
          config: const RouteApiConfig(token: 'test-placeholder'),
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/v1/routes');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              body['drawing'],
              snapshot.points.map((p) => [p.dx, p.dy]).toList(),
            );
            expect(body.containsKey('shape'), isFalse);
            expect(body.containsKey('preset'), isFalse);
            expect(body['distance_m'], 5000);
            expect(body['location'], [127.1, 37.5]);
            return http.Response(
              jsonEncode({
                'api_version': 'v1',
                'source': 'osm',
                'found': true,
                'recommended_count': 1,
                'candidates': [
                  {'acceptable': false},
                  {
                    'acceptable': true,
                    'distance_m': 4900,
                    'approach_m': 120,
                    'geometry': {
                      'type': 'LineString',
                      'coordinates': [
                        [127.1, 37.5],
                        [127.11, 37.51],
                        [127.12, 37.52],
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );
        addTearDown(api.close);
        final result = await api.generate(
          RouteRequest(
            input: RouteGenerationInput(
              drawing: snapshot,
              minDistanceKm: 4,
              maxDistanceKm: 8,
            ),
            targetDistanceKm: 5,
            longitude: 127.1,
            latitude: 37.5,
          ),
        );
        expect(result, hasLength(1));
        expect(result.single.source, RouteDataSource.api);
        expect(result.single.distanceKm, 4.9);
        expect(result.single.coordinates.first.latitude, 37.5);
        expect(result.single.coordinates.first.longitude, 127.1);
        expect(result.single.coordinates, hasLength(3));
        expect(result.candidateCount, 2);
      },
    );
  }

  test('preset replacement, resize, manual transition and reset keep snapshots isolated', () {
    final drawing = DrawingController();
    addTearDown(drawing.dispose);
    drawing.selectPreset(DrawingPreset.star);
    expect(drawing.hasDrawing, isFalse); // No usable layout yet.
    drawing.updateViewport(const Size(300, 400));
    drawing.selectPreset(DrawingPreset.star);
    final star = drawing.snapshot()!;
    expect(star.strokes, hasLength(1));
    drawing.selectPreset(DrawingPreset.heart);
    expect(drawing.selectedPreset, DrawingPreset.heart);
    expect(drawing.snapshot()!.points, isNot(star.points));
    drawing.updateViewport(const Size(600, 240));
    expect(drawing.snapshot()!.canvasSize, const Size(600, 240));
    expect(
      drawing.snapshot()!.points,
      DrawingPreset.heart.pointsFor(const Size(600, 240)),
    );
    expect(star.canvasSize, const Size(300, 400));
    expect(star.points, DrawingPreset.star.pointsFor(const Size(300, 400)));
    drawing.beginStroke(const Offset(10, 20), const Size(600, 240));
    drawing.addPoint(const Offset(100, 80), const Size(600, 240));
    drawing.endStroke();
    expect(drawing.selectedPreset, isNull);
    expect(drawing.snapshot()!.strokes, [
      [const Offset(10, 20), const Offset(100, 80)],
    ]);
    drawing.selectPreset(DrawingPreset.crescent);
    drawing.clear();
    expect(drawing.selectedPreset, isNull);
    expect(drawing.snapshot(), isNull);
    expect(star.points.first, star.points.last);
  });
}
