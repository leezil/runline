import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../shared/widgets/runline_map_view.dart';
import 'recommended_route.dart';
import '../route_generation/route_api.dart';
import '../running/running_screen.dart';
import '../running/running_goal.dart';

/// Uses the existing response snapshot; starting never issues a new API call.
class RouteRecommendationScreen extends StatefulWidget {
  const RouteRecommendationScreen({
    super.key,
    required this.input,
    this.routes,
    this.result,
  });

  final RouteGenerationInput input;

  /// Null is the explicit developer preview; an empty API result stays empty.
  final List<RecommendedRoute>? routes;
  final RouteResult? result;

  @override
  State<RouteRecommendationScreen> createState() =>
      _RouteRecommendationScreenState();
}

class _RouteRecommendationScreenState extends State<RouteRecommendationScreen> {
  bool get _preview => widget.routes == null;
  late final List<RecommendedRoute> _routes = List.unmodifiable(
    _preview
        ? mockRecommendedRoutes
        : widget.routes!.where((route) => route.source == RouteDataSource.api),
  );
  late RecommendedRoute? _selection = _routes.firstOrNull;
  RecommendedRoute get _selectedRoute => _selection!;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('추천 러닝 경로')),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_preview)
              const Text(
                '개발용 Mock Data · 실제 추천 경로가 아닙니다.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            if (_preview)
              const Text(
                '좌표·거리·시간은 화면 확인용 예시이며, 그린 모양이나 선택 거리로 생성되지 않았습니다. 실제 이동에 사용하지 마세요.',
              ),
            if (!_preview && widget.result?.source != 'synthetic')
              const Text('실제 OSM 추천 경로 · © OpenStreetMap contributors'),
            if (widget.result?.source == 'synthetic')
              const Text('연결 테스트 결과 · synthetic 가상 도로이며 실제 러닝 코스가 아닙니다.'),
            if (_routes.isEmpty)
              const Text(
                '추천 가능한 경로가 없습니다. 거리·그림·기준 위치를 변경하여 다시 시도해주세요.',
                key: Key('empty-routes'),
              ),
            if (widget.result case final result?) ...[
              if (result.message?.isNotEmpty == true)
                Text(
                  '서버 안내: ${result.message}',
                  key: const Key('server-message'),
                ),
              for (final warning in result.warnings) Text('서버 경고: $warning'),
              if (result.data['warnings'] != null)
                Text('도로 데이터 경고: ${result.data['warnings']}'),
              if (result.data['warning'] != null)
                Text('도로 데이터 경고: ${result.data['warning']}'),
              ExpansionTile(
                title: const Text('요청·응답 확인'),
                children: [
                  Text('POST /v1/routes · HTTP ${result.httpStatus ?? '미기록'}'),
                  Text(
                    'found: ${result.found} · recommended_count: ${result.recommendedCount ?? '미제공'}',
                  ),
                  Text(
                    'candidates: ${result.candidateCount} · acceptable=true: ${result.acceptableCount} · 표시 추천: ${result.length}',
                  ),
                  Text(
                    'source: ${result.source} · request_id: ${result.requestId ?? '미제공'}',
                  ),
                  if (result.elapsedSeconds != null)
                    Text('전체 처리 시간: ${result.elapsedSeconds}초'),
                  if (result.data['osm_provider'] != null)
                    Text('OSM 제공자: ${result.data['osm_provider']}'),
                  if (result.data['osm_timestamp'] != null)
                    Text('OSM 데이터 시각: ${result.data['osm_timestamp']}'),
                  if (result.requestPayload case final payload?) ...[
                    Text(
                      'drawing: ${(payload['drawing'] as List).length}개 · location [경도, 위도]: ${payload['location']}',
                    ),
                    Text(
                      'distance_m: ${payload['distance_m']} · approach_m: ${payload['approach_m']} · tolerance: ${payload['tolerance']}',
                    ),
                    Text(
                      'radius_m: ${payload['radius_m']} · search_seconds: ${payload['search_seconds']}',
                    ),
                    Text(
                      'route_type: ${payload['route_type']} · search_mode: ${payload['search_mode']}',
                    ),
                  ],
                ],
              ),
              if (result.comparisons.isNotEmpty) ...[
                const Text('비교용 후보 · 추천 및 러닝에 사용할 수 없습니다.'),
                for (final route in result.comparisons)
                  ListTile(
                    title: Text(
                      '${route.name} · ${result.source == 'synthetic' ? '가상 도로' : 'acceptable=false'}',
                    ),
                    subtitle: Text(
                      '코스 거리 ${(route.distanceKm * 1000).toStringAsFixed(1)} m${route.approachMeters == null ? '' : ' · 접근 거리 ${route.approachMeters!.toStringAsFixed(1)} m'}',
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 12),
            if (_selection != null) ...[
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColoredBox(
                    color: AppColors.border,
                    child: RunlineMapView(
                      routeCoordinates: _selectedRoute.coordinates,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _preview
                    ? '지도 예시: ${_selectedRoute.name} · Mock'
                    : '선택 경로: ${_selectedRoute.name} · OSM',
                key: const Key('selected-route-label'),
              ),
            ],
            const SizedBox(height: 16),
            for (final route in _routes) ...[
              Semantics(
                selected: identical(route, _selectedRoute),
                button: true,
                child: Material(
                  key: ValueKey(route.id),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: identical(route, _selectedRoute)
                          ? AppColors.primary
                          : AppColors.border,
                      width: identical(route, _selectedRoute) ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _selection = route),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${route.name} · ${_preview ? 'Mock' : 'OSM'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _preview
                                ? '예시 ${route.distanceKm.toStringAsFixed(1)} km · 약 ${route.estimatedDuration.inMinutes}분'
                                : '실제 코스 거리 ${(route.distanceKm * 1000).toStringAsFixed(1)} m',
                          ),
                          if (!_preview && route.approachMeters != null)
                            Text(
                              '기준 위치 → 코스 시작점 접근 거리 ${route.approachMeters!.toStringAsFixed(1)} m',
                            ),
                          if (identical(route, _selectedRoute))
                            const Text(
                              '선택됨',
                              style: TextStyle(color: AppColors.primary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              _preview
                  ? 'Mock 경로로는 러닝을 시작할 수 없습니다.'
                  : '선택한 코스를 표시하며 GPS로 실제 이동을 측정합니다.',
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('route-running-start'),
              onPressed:
                  _preview ||
                      _selection == null ||
                      !_selectedRoute.canRun ||
                      widget.result?.source == 'synthetic'
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RunningScreen(
                          selectedRoute: _selectedRoute,
                          goal: RunningGoal.distance(_selectedRoute.distanceKm),
                        ),
                      ),
                    ),
              child: const Text('러닝 시작'),
            ),
          ],
        ),
      ),
    ),
  );
}
