import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/facilities/facility.dart';
import 'package:runline/features/facilities/facility_api.dart';

Map<String, Object?> facilityJson() => {
  'id': 'toilet-1',
  'type': 'toilet',
  'name': '공원 화장실',
  'location': [127.01, 37.26],
  'address': {'road': '공원로 1', 'lot': null},
  'details': {'opening_hours_text': '상시', 'opening_hours_detail': null},
  'coordinate_source': 'juso',
  'source_date': '20261112',
};

void main() {
  test(
    'uses authenticated GET and preserves longitude/latitude contract',
    () async {
      final api = FacilityApi(
        baseUrl: 'https://example.test/',
        token: 'test-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/places');
          expect(request.url.queryParameters['types'], 'cctv,toilet');
          expect(request.url.queryParameters['limit'], '200');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.headers['ngrok-skip-browser-warning'], '1');
          return http.Response(
            jsonEncode({
              'items': [facilityJson()],
              'truncated': true,
              'sources': [
                {'last_import_failed': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final result = await api.fetch(
        const FacilityBounds(127, 37.25, 127.02, 37.27),
        FacilityType.values.toSet(),
      );
      expect(result.items.single.position.latitude, 37.26);
      expect(result.items.single.position.longitude, 127.01);
      expect(result.items.single.name, '공원 화장실');
      expect(result.truncated, true);
      expect(result.notice, isNotNull);
    },
  );

  test('reports rate limit without exposing raw response or token', () async {
    final api = FacilityApi(
      baseUrl: 'https://example.test',
      token: 'secret',
      client: MockClient(
        (_) async => http.Response(
          'secret upstream failure',
          429,
          headers: {'retry-after': '90'},
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.fetch(const FacilityBounds(127, 37.25, 127.02, 37.27), {
        FacilityType.cctv,
      }),
      throwsA(
        isA<FacilityApiException>()
            .having((e) => e.retryAfter, 'delay', const Duration(seconds: 90))
            .having((e) => e.message, 'message', isNot(contains('secret'))),
      ),
    );
  });

  test('malformed coordinates are rejected instead of placed on the map', () {
    expect(
      () => Facility.fromJson({
        ...facilityJson(),
        'location': [37.26, 127.01],
      }),
      throwsFormatException,
    );
    expect(const FacilityBounds(124, 32, 132, 39).queryable, false);
  });
}
