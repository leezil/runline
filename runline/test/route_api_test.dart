import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/route_drawing/drawing_controller.dart';
import 'package:runline/features/route_generation/route_api.dart';
import 'package:runline/features/route_recommendation/recommended_route.dart';

DrawingData sampleDrawing({List<List<Offset>>? strokes}) => DrawingData(
  canvasSize: const Size(500, 400),
  strokes:
      strokes ??
      [
        [const Offset(20, 30), const Offset(80, 90), const Offset(120, 70)],
      ],
);
RouteRequest sampleRequest({
  double target = 5.125,
  DrawingData? drawing,
  double longitude = 127.1,
}) => RouteRequest(
  input: RouteGenerationInput(
    drawing: drawing ?? sampleDrawing(),
    minDistanceKm: 4,
    maxDistanceKm: 8,
  ),
  targetDistanceKm: target,
  longitude: longitude,
  latitude: 37.5,
);
Map<String, Object> candidate({
  bool acceptable = true,
  double distance = 5125,
  double approach = 124.5,
}) => {
  'acceptable': acceptable,
  'distance_m': distance,
  'approach_m': approach,
  'geometry': {
    'type': 'LineString',
    'coordinates': [
      [127.1, 37.5],
      [127.2, 37.6],
      [127.3, 37.7],
    ],
  },
};
Map<String, Object> responseBody(
  List<Object> candidates, {
  bool found = true,
}) => {
  'api_version': 'v1',
  'source': 'osm',
  'found': found,
  'recommended_count': 99,
  'candidates': candidates,
};

void main() {
  test('latest documented response accepts missing approach and retains diagnostics', () {
    final value = candidate()..remove('approach_m');
    final result = parseRoutes(
      {
        ...responseBody([value, candidate(acceptable: false)]),
        'message': '부분 조건 일치',
        'request_id': 'test-request-1',
        'total_elapsed_s': 1.5,
        'warnings': ['탐색 시간 제한'],
        'data': {
          'osm_provider': 'local_korea',
          'warnings': ['캐시 사용'],
        },
      },
      httpStatus: 200,
      requestPayload: sampleRequest().toJson(),
    );
    expect(result, hasLength(1));
    expect(result.single.approachMeters, isNull);
    expect(result.candidateCount, 2);
    expect(result.acceptableCount, 1);
    expect(result.recommendedCount, 99);
    expect(result.comparisons, hasLength(1));
    expect(result.httpStatus, 200);
    expect(result.requestId, 'test-request-1');
    expect(result.message, '부분 조건 일치');
    expect(result.elapsedSeconds, 1.5);
    expect(result.warnings, ['탐색 시간 제한']);
    expect(result.data['osm_provider'], 'local_korea');
    expect(result.requestPayload!['distance_m'], 5125);
    final empty = parseRoutes({
      ...responseBody([], found: false),
      'message': '조건에 맞는 도로 없음',
    });
    expect(empty.message, '조건에 맞는 도로 없음');
    expect(empty, isEmpty);
  });

  test('synthetic candidates remain comparison only; nonboolean acceptable is an error', () {
    final result = parseRoutes({
      ...responseBody([candidate()]),
      'source': 'synthetic',
    });
    expect(result, isEmpty);
    expect(result.acceptableCount, 1);
    expect(result.comparisons.single.source, RouteDataSource.synthetic);
    expect(
      () => parseRoutes(
        responseBody([
          {...candidate(), 'acceptable': 'true'},
        ]),
      ),
      throwsA(isA<RouteApiException>()),
    );
  });

  test('latest input bounds reject unsupported distance, Korea location and point count', () {
    RouteRequest request(double km, double lon, double lat) => RouteRequest(
      input: RouteGenerationInput(
        drawing: sampleDrawing(),
        minDistanceKm: .1,
        maxDistanceKm: 15,
      ),
      targetDistanceKm: km,
      longitude: lon,
      latitude: lat,
    );
    for (final km in [.299, 8.001]) {
      expect(
        () => request(km, 127, 37).toJson(),
        throwsA(isA<RouteApiException>()),
      );
    }
    for (final km in [.3, 8.0]) {
      expect(request(km, 124, 32).toJson()['distance_m'], (km * 1000).round());
      expect(request(km, 132, 39).toJson()['location'], [132, 39]);
    }
    for (final location in [
      [123.99, 37.0],
      [132.01, 37.0],
      [127.0, 31.99],
      [127.0, 39.01],
      [37.5, 127.0],
    ]) {
      expect(
        () => request(2, location[0], location[1]).toJson(),
        throwsA(isA<RouteApiException>()),
      );
    }
    expect(
      () => serializeDrawing(
        sampleDrawing(
          strokes: [List.generate(3001, (i) => Offset(i % 500, i % 400))],
        ),
      ),
      throwsA(isA<RouteApiException>()),
    );
  });

  test('all search options serialize, local focus is mandatory and enums/ranges are checked', () {
    const options = RouteSearchOptions(
      approachMeters: 500,
      tolerance: .3,
      candidateLimit: 5,
      routeType: 'loop',
      searchMode: 'local',
      focusLongitude: 127.1,
      focusLatitude: 37.5,
      radiusMeters: 4000,
      searchSeconds: 15,
      allowRotation: false,
      allowVertexAdjustment: false,
      dataSource: 'demo',
    );
    expect(options.toJson(), {
      'approach_m': 500.0,
      'tolerance': .3,
      'candidate_limit': 5,
      'route_type': 'loop',
      'search_mode': 'local',
      'focus_location': [127.1, 37.5],
      'radius_m': 4000.0,
      'search_seconds': 15.0,
      'allow_rotation': false,
      'allow_vertex_adjustment': false,
      'data_source': 'demo',
      'provider': 'local',
    });
    expect(
      const RouteSearchOptions(
        focusLongitude: 127,
        focusLatitude: 37,
      ).toJson().containsKey('focus_location'),
      isFalse,
    );
    for (final invalid in [
      const RouteSearchOptions(approachMeters: -1),
      const RouteSearchOptions(approachMeters: 1501),
      const RouteSearchOptions(tolerance: .04),
      const RouteSearchOptions(tolerance: .51),
      const RouteSearchOptions(candidateLimit: 0),
      const RouteSearchOptions(candidateLimit: 31),
      const RouteSearchOptions(radiusMeters: 799),
      const RouteSearchOptions(radiusMeters: 4001),
      const RouteSearchOptions(searchSeconds: 2),
      const RouteSearchOptions(searchSeconds: 46),
      const RouteSearchOptions(routeType: 'invalid'),
      const RouteSearchOptions(searchMode: 'invalid'),
      const RouteSearchOptions(searchMode: 'local'),
      const RouteSearchOptions(dataSource: 'synthetic'),
      const RouteSearchOptions(provider: 'external'),
    ]) {
      expect(invalid.toJson, throwsA(isA<RouteApiException>()));
    }
  });

  test(
    'health rejects local port and unexpected shape without using auth',
    () async {
      for (final value in [
        {'ok': true, 'version': 'v1', 'local_only': true},
        {'status': 'ok'},
      ]) {
        final api = RouteApi(
          config: const RouteApiConfig(token: 'test-placeholder'),
          client: MockClient((request) async {
            expect(request.headers.containsKey('authorization'), isFalse);
            return http.Response(jsonEncode(value), 200);
          }),
        );
        addTearDown(api.close);
        await expectLater(api.health(), throwsA(isA<RouteApiException>()));
      }
    },
  );
  test(
    'actual controller snapshot serializes in drawing order without scaling',
    () {
      final controller = DrawingController();
      addTearDown(controller.dispose);
      controller.beginStroke(const Offset(20, 30), const Size(500, 400));
      controller.addPoint(const Offset(80, 90), const Size(500, 400));
      controller.endStroke();
      final json = sampleRequest(drawing: controller.snapshot()).toJson();
      expect(json, {
        'drawing': [
          [20.0, 30.0],
          [80.0, 90.0],
        ],
        'location': [127.1, 37.5],
        'distance_m': 5125,
        ...const RouteSearchOptions().toJson(),
      });
      expect(
        () => sampleRequest(target: 9).toJson(),
        throwsA(isA<RouteApiException>()),
      );
      expect(
        () => sampleRequest(longitude: double.nan).toJson(),
        throwsA(isA<RouteApiException>()),
      );
    },
  );

  test(
    'invalid, empty, out-of-bounds and multiple strokes are never joined',
    () {
      for (final strokes in <List<List<Offset>>>[
        [],
        [[]],
        [
          [const Offset(1, 1)],
        ],
        [
          [const Offset(1, 1), const Offset(1, 1)],
        ],
        [
          [const Offset(-1, 0), const Offset(2, 2)],
        ],
        [
          [const Offset(0, 0), const Offset(501, 400)],
        ],
        [
          [const Offset(1, 1), const Offset(2, 2)],
          [const Offset(3, 3), const Offset(4, 4)],
        ],
      ]) {
        expect(
          () => serializeDrawing(sampleDrawing(strokes: strokes)),
          throwsA(isA<RouteApiException>()),
        );
      }
    },
  );

  test(
    'filters acceptable, ignores count, keeps distances and all GeoJSON points',
    () {
      final routes = parseRoutes(
        responseBody([candidate(acceptable: false), candidate()]),
      );
      expect(routes, hasLength(1));
      expect(routes.single.isMock, isFalse);
      expect(routes.single.distanceKm, 5.125);
      expect(routes.single.approachMeters, 124.5);
      expect(routes.single.coordinates, hasLength(3));
      expect(routes.single.coordinates.first.latitude, 37.5);
      expect(routes.single.coordinates.first.longitude, 127.1);
      expect(parseRoutes(responseBody([], found: false)), isEmpty);
      expect(
        parseRoutes(responseBody([candidate(acceptable: false)])),
        isEmpty,
      );
      expect(
        () => parseRoutes(responseBody([candidate(distance: -1)])),
        throwsA(isA<RouteApiException>()),
      );
      expect(
        () => parseRoutes({'candidates': []}),
        throwsA(isA<RouteApiException>()),
      );
    },
  );

  test(
    'POST endpoint, JSON, auth and ngrok headers; GET health supported',
    () async {
      final calls = <http.Request>[];
      final api = RouteApi(
        config: const RouteApiConfig(token: 'unit-test-placeholder'),
        client: MockClient((request) async {
          calls.add(request);
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {'ok': true, 'version': 'v1', 'local_only': false}
                  : responseBody([candidate()]),
            ),
            200,
          );
        }),
      );
      addTearDown(api.close);
      expect(await api.health(), {
        'ok': true,
        'version': 'v1',
        'local_only': false,
      });
      expect(calls.first.headers.containsKey('authorization'), isFalse);
      expect(await api.generate(sampleRequest()), hasLength(1));
      expect(calls.last.url.path, '/v1/routes');
      expect(calls.last.method, 'POST');
      // Compare booleans to keep even the test fixture out of failure logs.
      expect(
        calls.last.headers['authorization'] == 'Bearer unit-test-placeholder',
        isTrue,
      );
      expect(calls.last.headers['ngrok-skip-browser-warning'], '1');
      expect(calls.last.headers['content-type'], contains('application/json'));
      expect(jsonDecode(calls.last.body), sampleRequest().toJson());
    },
  );

  test(
    'missing token and invalid location cannot issue a network request',
    () async {
      var calls = 0;
      final api = RouteApi(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.generate(sampleRequest()),
        throwsA(isA<RouteApiException>()),
      );
      expect(calls, 0);
    },
  );

  for (final code in [400, 401, 403, 413, 415, 422, 429, 500, 502]) {
    test('HTTP $code is handled before parsing HTML', () async {
      final api = RouteApi(
        config: const RouteApiConfig(token: 'test-placeholder'),
        client: MockClient(
          (_) async => http.Response('<html>private response</html>', code),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.generate(sampleRequest()),
        throwsA(
          isA<RouteApiException>()
              .having((e) => e.statusCode, 'status', code)
              .having(
                (e) => e.message.contains('private response'),
                'body hidden',
                false,
              ),
        ),
      );
    });
  }

  test(
    'malformed JSON, HTML and broken candidate schema produce safe errors',
    () async {
      for (final body in [
        '<html/>',
        '{',
        '[]',
        '{"api_version":"v1","source":"osm","found":true,"candidates":[{"acceptable":true}]}',
      ]) {
        final api = RouteApi(
          config: const RouteApiConfig(token: 'test-placeholder'),
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(api.close);
        await expectLater(
          api.generate(sampleRequest()),
          throwsA(isA<RouteApiException>()),
        );
      }
    },
  );

  test('timeout, network failure and duplicate in-flight requests', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final api = RouteApi(
      config: const RouteApiConfig(token: 'test-placeholder'),
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(api.close);
    final first = api.generate(sampleRequest());
    await expectLater(
      api.generate(sampleRequest()),
      throwsA(isA<RouteApiException>()),
    );
    await expectLater(
      first,
      throwsA(
        isA<RouteApiException>().having(
          (e) => e.message,
          'timeout',
          contains('서버 계산'),
        ),
      ),
    );
    expect(calls, 1);
    pending.complete(http.Response('{}', 200));
    final offline = RouteApi(
      config: const RouteApiConfig(token: 'test-placeholder'),
      client: MockClient(
        (_) async => throw http.ClientException('hidden details'),
      ),
    );
    addTearDown(offline.close);
    await expectLater(offline.health(), throwsA(isA<RouteApiException>()));
  });

  for (final header in ['30', 'Fri, 06 Nov 2026 00:00:30 GMT']) {
    test('Retry-After $header blocks retry until deadline', () async {
      var now = DateTime.utc(2026, 11, 6);
      var calls = 0;
      final api = RouteApi(
        config: const RouteApiConfig(token: 'test-placeholder'),
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 429, headers: {'retry-after': header});
        }),
      );
      addTearDown(api.close);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          api.generate(sampleRequest()),
          throwsA(
            isA<RouteApiException>().having(
              (e) => e.retryAt,
              'deadline',
              DateTime.utc(2026, 11, 6, 0, 0, 30),
            ),
          ),
        );
      }
      expect(calls, 1);
      now = now.add(const Duration(seconds: 31));
      await expectLater(
        api.generate(sampleRequest()),
        throwsA(isA<RouteApiException>()),
      );
      expect(calls, 2);
    });
  }
}
