import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

import '../route_drawing/drawing_controller.dart';
import '../route_recommendation/recommended_route.dart';

class RouteApiConfig {
  const RouteApiConfig({
    this.baseUrl = const String.fromEnvironment(
      'ROUTE_API_BASE_URL',
      defaultValue: 'https://01b0-61-98-40-101.ngrok-free.app',
    ),
    this.token = const String.fromEnvironment('ROUTE_API_TOKEN'),
  });

  final String baseUrl;
  final String token;
  bool get hasToken => token.trim().isNotEmpty;

  Uri endpoint(String path) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const RouteApiException(
        'ROUTE_API_BASE_URL에 올바른 HTTPS 주소를 설정해주세요.',
      );
    }
    return uri.replace(
      path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}$path',
    );
  }
}

class RouteApiException implements Exception {
  const RouteApiException(this.message, {this.statusCode, this.retryAt});
  final String message;
  final int? statusCode;
  final DateTime? retryAt;
  @override
  String toString() => message;
}

/// v1 has no pen-lift markers. Reject multiple strokes rather than invent edges.
List<List<double>> serializeDrawing(DrawingData drawing) {
  final size = drawing.canvasSize;
  if (!size.isFinite || size.isEmpty || drawing.strokes.length != 1) {
    throw const RouteApiException('현재 API는 한 획 그림만 지원합니다. 초기화 후 한 획으로 그려주세요.');
  }
  final points = drawing.strokes.single;
  if (points.length < 2 ||
      points.length > 3000 ||
      points.every((p) => p == points.first) ||
      points.any(
        (p) =>
            !p.dx.isFinite ||
            !p.dy.isFinite ||
            p.dx < 0 ||
            p.dy < 0 ||
            p.dx > size.width ||
            p.dx > 10000 ||
            p.dy > size.height ||
            p.dy > 10000,
      )) {
    throw const RouteApiException(
      '캔버스 안에 유효한 선을 그려주세요. 좌표는 2~3,000개, 각 값은 최대 10,000까지 지원합니다.',
    );
  }
  return points.map((p) => [p.dx, p.dy]).toList();
}

class RouteSearchOptions {
  const RouteSearchOptions({
    this.approachMeters = 1000,
    this.tolerance = .2,
    this.candidateLimit = 20,
    this.routeType = 'auto',
    this.searchMode = 'overview',
    this.focusLongitude,
    this.focusLatitude,
    this.allowRotation = true,
    this.allowVertexAdjustment = true,
    this.radiusMeters = 2500,
    this.searchSeconds = 45,
    this.dataSource = 'osm',
    this.provider = 'local',
  });
  final double approachMeters, tolerance, radiusMeters, searchSeconds;
  final int candidateLimit;
  final String routeType, searchMode, dataSource, provider;
  final double? focusLongitude, focusLatitude;
  final bool allowRotation, allowVertexAdjustment;

  Map<String, Object> toJson() {
    bool between(double value, double min, double max) =>
        value.isFinite && value >= min && value <= max;
    if (!between(approachMeters, 0, 1500) ||
        !between(tolerance, .05, .5) ||
        candidateLimit < 1 ||
        candidateLimit > 30 ||
        !between(radiusMeters, 800, 4000) ||
        !between(searchSeconds, 3, 45) ||
        !['auto', 'open', 'loop'].contains(routeType) ||
        !['overview', 'all', 'local'].contains(searchMode) ||
        !['osm', 'demo'].contains(dataSource) ||
        provider != 'local') {
      throw const RouteApiException(
        '탐색 설정이 API 허용 범위를 벗어났습니다. 각 항목의 범위와 선택값을 확인해주세요.',
      );
    }
    if (searchMode == 'local') {
      validateKoreaLocation(focusLongitude, focusLatitude);
    }
    return {
      'approach_m': approachMeters,
      'tolerance': tolerance,
      'candidate_limit': candidateLimit,
      'route_type': routeType,
      'search_mode': searchMode,
      if (searchMode == 'local')
        'focus_location': [focusLongitude!, focusLatitude!],
      'allow_rotation': allowRotation,
      'allow_vertex_adjustment': allowVertexAdjustment,
      'radius_m': radiusMeters,
      'search_seconds': searchSeconds,
      'data_source': dataSource,
      'provider': provider,
    };
  }
}

void validateKoreaLocation(double? longitude, double? latitude) {
  if (longitude == null ||
      latitude == null ||
      !longitude.isFinite ||
      !latitude.isFinite ||
      longitude < 124 ||
      longitude > 132 ||
      latitude < 32 ||
      latitude > 39) {
    throw const RouteApiException(
      '한국 도로 기준 위치를 [경도 124~132, 위도 32~39] 범위로 입력해주세요. local 탐색은 상세 탐색 위치도 필요합니다.',
    );
  }
}

class RouteRequest {
  RouteRequest({
    required this.input,
    required this.targetDistanceKm,
    required this.longitude,
    required this.latitude,
    this.options = const RouteSearchOptions(),
  });
  final RouteGenerationInput input;
  final double targetDistanceKm;
  final double longitude;
  final double latitude;
  final RouteSearchOptions options;

  Map<String, Object> toJson() {
    if (!input.minDistanceKm.isFinite ||
        !input.maxDistanceKm.isFinite ||
        input.minDistanceKm <= 0 ||
        input.maxDistanceKm < input.minDistanceKm ||
        !targetDistanceKm.isFinite ||
        targetDistanceKm < input.minDistanceKm ||
        targetDistanceKm > input.maxDistanceKm) {
      throw const RouteApiException('선택한 거리 범위 안에서 목표 거리(km)를 입력해주세요.');
    }
    if (targetDistanceKm < .3 || targetDistanceKm > 8) {
      throw const RouteApiException(
        '서버가 지원하는 목표 거리는 0.3~8 km입니다. 선택한 거리 범위 안에서 이 조건에 맞는 거리를 입력해주세요.',
      );
    }
    validateKoreaLocation(longitude, latitude);
    final result = <String, Object>{
      'drawing': serializeDrawing(input.drawing),
      'location': [longitude, latitude],
      'distance_m': (targetDistanceKm * 1000).round(),
      ...options.toJson(),
    };
    if (utf8.encode(jsonEncode(result)).length > 256 * 1024) {
      throw const RouteApiException('요청 본문은 최대 256 KiB입니다. 그림을 더 간단하게 그려주세요.');
    }
    return result;
  }
}

/// Immutable recommended list with server metadata retained even for zero results.
class RouteResult extends ListBase<RecommendedRoute> {
  RouteResult({
    required Iterable<RecommendedRoute> routes,
    required this.found,
    required this.source,
    required this.candidateCount,
    required this.acceptableCount,
    this.recommendedCount,
    this.message,
    this.requestId,
    this.elapsedSeconds,
    this.httpStatus,
    Iterable<RecommendedRoute> comparisons = const [],
    Iterable<String> warnings = const [],
    Map<String, dynamic> data = const {},
    this.requestPayload,
  }) : _routes = List.unmodifiable(routes),
       comparisons = List.unmodifiable(comparisons),
       warnings = List.unmodifiable(warnings),
       data = Map.unmodifiable(data);
  final List<RecommendedRoute> _routes;
  final bool found;
  final String source;
  final int candidateCount, acceptableCount;
  final int? recommendedCount, httpStatus;
  final String? message, requestId;
  final double? elapsedSeconds;
  final List<RecommendedRoute> comparisons;
  final List<String> warnings;
  final Map<String, dynamic> data;
  final Map<String, Object>? requestPayload;
  @override
  int get length => _routes.length;
  @override
  set length(int value) => throw UnsupportedError('Immutable result');
  @override
  RecommendedRoute operator [](int index) => _routes[index];
  @override
  void operator []=(int index, RecommendedRoute value) =>
      throw UnsupportedError('Immutable result');
}

/// Injectable boundary: a production relay can implement this without UI changes.
abstract interface class RouteService {
  Future<Map<String, dynamic>> health();
  Future<RouteResult> generate(RouteRequest request);
  void close();
}

class RouteApi implements RouteService {
  RouteApi({
    this.config = const RouteApiConfig(),
    http.Client? client,
    this.timeout = const Duration(seconds: 120),
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;
  final RouteApiConfig config;
  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _now;
  bool _generating = false;
  DateTime? _retryAt;

  @override
  Future<Map<String, dynamic>> health() async {
    final response = await _send('GET', '/v1/health');
    final json = response.json;
    if (json['ok'] != true ||
        json['version'] != 'v1' ||
        json['local_only'] != false) {
      throw const RouteApiException(
        '외부용 API v1 health 응답이 아닙니다. ngrok 대상 포트 8083과 서버 상태를 확인해주세요.',
      );
    }
    return json;
  }

  @override
  Future<RouteResult> generate(RouteRequest request) async {
    if (_generating) throw const RouteApiException('이미 경로를 생성하고 있습니다.');
    if (!config.hasToken) {
      throw const RouteApiException(
        '로컬 설정 파일에 ROUTE_API_TOKEN을 입력하고 앱을 다시 실행해주세요.',
      );
    }
    _generating = true;
    try {
      final body = request.toJson();
      final response = await _send('POST', '/v1/routes', body: body);
      return parseRoutes(
        response.json,
        httpStatus: response.status,
        requestPayload: body,
      );
    } finally {
      _generating = false;
    }
  }

  Future<({Map<String, dynamic> json, int status})> _send(
    String method,
    String path, {
    Map<String, Object>? body,
  }) async {
    final retryAt = _retryAt;
    if (retryAt != null && _now().isBefore(retryAt)) {
      throw RouteApiException(
        '요청 제한 중입니다. 안내된 대기 시간 후 다시 시도해주세요.',
        statusCode: 429,
        retryAt: retryAt,
      );
    }
    final uri = config.endpoint(path);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': '1',
      if (method == 'POST' && config.hasToken)
        'Authorization': 'Bearer ${config.token.trim()}',
    };
    try {
      final response =
          await (method == 'GET'
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(timeout);
      // Never parse or surface an error body: ngrok may return HTML or secrets.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 429) {
          final raw = response.headers['retry-after'];
          final seconds = int.tryParse(raw ?? '');
          DateTime? date;
          if (seconds == null && raw != null) {
            date = parseRetryAfterDate(raw);
          }
          _retryAt = seconds != null && seconds >= 0
              ? _now().add(Duration(seconds: seconds))
              : date;
        }
        throw RouteApiException(
          _statusMessage(response.statusCode),
          statusCode: response.statusCode,
          retryAt: _retryAt,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return (json: decoded, status: response.statusCode);
    } on RouteApiException {
      rethrow;
    } on TimeoutException {
      throw const RouteApiException(
        '120초 안에 응답하지 않았습니다. 서버 계산은 계속될 수 있으니 잠시 후 다시 시도해주세요.',
      );
    } on FormatException {
      throw const RouteApiException(
        '서버 응답이 올바른 JSON 형식이 아닙니다. ngrok 주소와 서버 상태를 확인해주세요.',
      );
    } catch (_) {
      throw const RouteApiException(
        '서버에 연결할 수 없습니다. 서버 실행 여부, ngrok 주소와 네트워크를 확인해주세요. Web은 localhost:5000 Origin 및 CORS 설정도 확인해주세요.',
      );
    }
  }

  @override
  void close() => _client.close();
}

// IMF-fixdate (HTTP-date), shared by browsers and native clients.
DateTime? parseRetryAfterDate(String value) {
  final match = RegExp(
    r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(value);
  if (match == null) return null;
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ].indexOf(match[2]!);
  if (month < 0) return null;
  return DateTime.utc(
    int.parse(match[3]!),
    month + 1,
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
}

String _statusMessage(int code) => switch (code) {
  400 => '요청 형식이 올바르지 않습니다. 그림·거리·위치를 확인해주세요. (400)',
  401 => '인증에 실패했습니다. API 토큰 설정을 확인해주세요. (401)',
  403 =>
    '접근이 거부되었습니다. 토큰 권한과 Web Origin(localhost:5000), 서버 CORS 설정을 확인해주세요. (403)',
  413 => '그림 데이터가 너무 큽니다. 더 간단한 그림으로 시도해주세요. (413)',
  415 => '서버가 요청 데이터 형식을 지원하지 않습니다. (415)',
  422 => '그림·거리·위치가 서버 조건에 맞지 않습니다. 입력을 변경해주세요. (422)',
  429 => '요청이 너무 많습니다. Retry-After 대기 시간 후 다시 시도해주세요. (429)',
  500 => '경로 생성 서버에 오류가 발생했습니다. 잠시 후 다시 시도해주세요. (500)',
  502 => '서버 연결이 불안정합니다. 서버 실행 여부와 ngrok 주소를 확인해주세요. (502)',
  _ => '서버 요청에 실패했습니다. (HTTP $code)',
};

RouteResult parseRoutes(
  Map<String, dynamic> json, {
  int? httpStatus,
  Map<String, Object>? requestPayload,
}) {
  try {
    if (json['api_version'] != 'v1' ||
        !['osm', 'synthetic'].contains(json['source']) ||
        json['found'] is! bool ||
        json['candidates'] is! List) {
      throw const FormatException();
    }
    final routes = <RecommendedRoute>[];
    final comparisons = <RecommendedRoute>[];
    var acceptableCount = 0;
    for (final (index, candidate) in (json['candidates'] as List).indexed) {
      if (candidate is! Map<String, dynamic>) throw const FormatException();
      if (candidate['acceptable'] is! bool) throw const FormatException();
      final acceptable = candidate['acceptable'] == true;
      if (acceptable) acceptableCount++;
      // Rejected candidates may omit geometry; retain their total count regardless.
      if (!acceptable &&
          (candidate['geometry'] == null || candidate['distance_m'] == null)) {
        continue;
      }
      final distance = (candidate['distance_m'] as num).toDouble();
      final approach = (candidate['approach_m'] as num?)?.toDouble();
      final geometry = candidate['geometry'] as Map<String, dynamic>;
      if (!distance.isFinite ||
          distance <= 0 ||
          (approach != null && (!approach.isFinite || approach < 0)) ||
          geometry['type'] != 'LineString') {
        throw const FormatException();
      }
      final points = (geometry['coordinates'] as List).map((point) {
        if (point is! List || point.length < 2) throw const FormatException();
        final lon = (point[0] as num).toDouble();
        final lat = (point[1] as num).toDouble();
        if (!lon.isFinite ||
            !lat.isFinite ||
            lon.abs() > 180 ||
            lat.abs() > 90) {
          throw const FormatException();
        }
        return LatLng(lat, lon);
      }).toList();
      if (points.length < 2 || (acceptable && json['found'] != true)) {
        throw const FormatException();
      }
      final recommended = acceptable && json['source'] == 'osm';
      (recommended ? routes : comparisons).add(
        RecommendedRoute(
          id: 'api-route-$index',
          name: recommended
              ? '추천 ${routes.length + 1}'
              : '비교 ${comparisons.length + 1}',
          distanceKm: distance / 1000,
          approachMeters: approach,
          estimatedDuration: Duration.zero,
          coordinates: points,
          source: json['source'] == 'osm'
              ? RouteDataSource.api
              : RouteDataSource.synthetic,
        ),
      );
    }
    return RouteResult(
      routes: routes,
      comparisons: comparisons,
      found: json['found'] as bool,
      source: json['source'] as String,
      candidateCount: (json['candidates'] as List).length,
      acceptableCount: acceptableCount,
      recommendedCount: json['recommended_count'] as int?,
      message: json['message'] as String?,
      requestId: json['request_id'] as String?,
      elapsedSeconds: (json['total_elapsed_s'] as num?)?.toDouble(),
      warnings: _warningMessages(json['warnings']),
      data: json['data'] as Map<String, dynamic>? ?? const {},
      httpStatus: httpStatus,
      requestPayload: requestPayload,
    );
  } catch (_) {
    throw const RouteApiException('경로 응답 형식이 올바르지 않습니다. 서버 API v1 명세를 확인해주세요.');
  }
}

List<String> _warningMessages(Object? value) => switch (value) {
  String text => [text],
  List values => values.whereType<String>().toList(),
  _ => const [],
};
