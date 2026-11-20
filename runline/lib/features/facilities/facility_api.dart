import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'facility.dart';

class FacilityApiException implements Exception {
  const FacilityApiException(this.message, {this.retryAfter});
  final String message;
  final Duration? retryAfter;
}

class FacilityResult {
  const FacilityResult(this.items, {required this.truncated, this.notice});
  final List<Facility> items;
  final bool truncated;
  final String? notice;
}

class FacilityApi {
  FacilityApi({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'PLACES_API_BASE_URL',
      defaultValue: String.fromEnvironment('ROUTE_API_BASE_URL'),
    ),
    this.token = const String.fromEnvironment(
      'PLACES_API_TOKEN',
      defaultValue: String.fromEnvironment('ROUTE_API_TOKEN'),
    ),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl, token;

  Future<FacilityResult> fetch(
    FacilityBounds bounds,
    Set<FacilityType> types,
  ) async {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        base.host.isEmpty ||
        !['https', 'http'].contains(base.scheme) ||
        token.trim().isEmpty) {
      throw const FacilityApiException('시설 API 주소와 토큰을 설정해주세요.');
    }
    if (!bounds.queryable || types.isEmpty) {
      throw const FacilityApiException('지도를 확대해 시설을 확인해주세요.');
    }
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/v1/places',
      queryParameters: {
        'types': (types.map((t) => t.name).toList()..sort()).join(','),
        'west': '${bounds.west}',
        'south': '${bounds.south}',
        'east': '${bounds.east}',
        'north': '${bounds.north}',
        'limit': '200',
      },
      fragment: '',
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer ${token.trim()}',
              'ngrok-skip-browser-warning': '1',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        throw FacilityApiException(
          switch (response.statusCode) {
            401 => '시설 API 토큰을 확인해주세요.',
            403 => '시설 API의 Web 허용 주소를 확인해주세요.',
            400 => '조회 범위를 확인하거나 지도를 확대해주세요.',
            429 => '요청이 많습니다. 잠시 후 다시 시도해주세요.',
            503 => '시설 데이터가 준비되지 않았습니다. 서버 상태를 확인해주세요.',
            _ => '시설을 불러오지 못했습니다. 다시 시도해주세요.',
          },
          retryAfter: response.statusCode == 429
              ? Duration(seconds: seconds.clamp(1, 3600))
              : null,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((item) => Facility.fromJson(item as Map<String, dynamic>))
          .toList();
      final sources = data['sources'] as List? ?? [];
      final stale = sources.any((s) => s['last_import_failed'] == true);
      return FacilityResult(
        List.unmodifiable(items),
        truncated: data['truncated'] as bool,
        notice: stale ? '일부 데이터 갱신에 실패해 이전 수집 결과를 표시합니다.' : null,
      );
    } on FacilityApiException {
      rethrow;
    } on TimeoutException {
      throw const FacilityApiException('시설 조회 시간이 초과되었습니다. 다시 시도해주세요.');
    } catch (_) {
      throw const FacilityApiException('시설 서버 연결 또는 응답을 확인해주세요.');
    }
  }

  void close() => _client.close();
}
