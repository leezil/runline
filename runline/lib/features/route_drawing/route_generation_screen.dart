import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'drawing_controller.dart';
import 'route_place_search.dart';
import '../route_generation/route_api.dart';
import '../route_recommendation/recommended_route.dart';
import '../route_recommendation/route_recommendation_screen.dart';
import '../running/running_location.dart';

class RouteGenerationScreen extends StatefulWidget {
  const RouteGenerationScreen({
    super.key,
    required this.drawing,
    this.minDistanceKm = 4,
    this.maxDistanceKm = 8,
    this.service,
    this.location,
    this.placeSearch,
    this.config = const RouteApiConfig(),
  });

  final DrawingData drawing;
  final double minDistanceKm;
  final double maxDistanceKm;
  final RouteService? service;
  final RunningLocation? location;
  final RoutePlaceSearch? placeSearch;
  final RouteApiConfig config;

  @override
  State<RouteGenerationScreen> createState() => _RouteGenerationScreenState();
}

enum _SearchRange {
  close('가까이', 500, .1, '500 m'),
  standard('보통', 1000, .2, '1 km'),
  wide('넓게', 1500, .3, '1.5 km');

  const _SearchRange(
    this.label,
    this.approachMeters,
    this.tolerance,
    this.approachLabel,
  );

  final String label;
  final double approachMeters;
  final double tolerance;
  final String approachLabel;
}

class _RouteGenerationScreenState extends State<RouteGenerationScreen> {
  final _target = TextEditingController();
  final _longitude = TextEditingController();
  final _latitude = TextEditingController();
  final _query = TextEditingController();
  _SearchRange _range = _SearchRange.standard;
  late final RouteService _service =
      widget.service ?? RouteApi(config: widget.config);
  bool _busy = false;
  bool _locating = false;
  bool _searching = false;
  bool _otherPlace = false;
  RoutePlace? _place;
  List<RoutePlace> _places = const [];
  String? _searchMessage;
  String? _message;
  bool get _canSearch => widget.placeSearch != null || canSearchRoutePlaces;
  double get _minTarget => math.max(.3, widget.minDistanceKm);
  double get _maxTarget => math.min(8, widget.maxDistanceKm);
  RouteGenerationInput get _input => RouteGenerationInput(
    drawing: widget.drawing,
    minDistanceKm: widget.minDistanceKm,
    maxDistanceKm: widget.maxDistanceKm,
  );

  @override
  void initState() {
    super.initState();
    if (_minTarget <= _maxTarget) {
      _target.text = ((_minTarget + _maxTarget) / 2).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _target.dispose();
    _longitude.dispose();
    _latitude.dispose();
    _query.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final query = _query.text.trim();
    if (_searching || query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _places = const [];
      _searchMessage = null;
    });
    try {
      final matches = await (widget.placeSearch ?? searchRoutePlaces)(query);
      if (!mounted) return;
      setState(() {
        _places = matches;
        if (matches.isEmpty) _searchMessage = '검색 결과가 없어요. 지역명이나 주소를 바꿔보세요.';
      });
    } catch (_) {
      if (mounted) setState(() => _searchMessage = '장소 검색에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectPlaceMode(bool otherPlace) {
    if (_otherPlace == otherPlace) return;
    setState(() {
      _otherPlace = otherPlace;
      _place = null;
      _longitude.clear();
      _latitude.clear();
      _message = null;
    });
  }

  Future<bool> _useCurrentLocation() async {
    if (_locating) return false;
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      final location = widget.location ?? GeolocatorRunningLocation();
      final status = await location.prepare();
      if (!mounted) return false;
      if (status != null) {
        throw const RouteApiException(
          '현재 위치를 가져올 수 없어요. 위치 권한을 확인하거나 다른 장소를 선택해주세요.',
        );
      }
      final fix = Completer<GpsPoint>();
      final subscription = location.positions().listen(
        (point) {
          if (!fix.isCompleted &&
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.accuracy.isFinite &&
              point.accuracy >= 0 &&
              point.accuracy <= 100) {
            fix.complete(point);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!fix.isCompleted) fix.completeError(error, stack);
        },
        onDone: () {
          if (!fix.isCompleted) fix.completeError(StateError('No GPS fix'));
        },
      );
      late final GpsPoint point;
      try {
        point = await fix.future.timeout(const Duration(seconds: 12));
      } finally {
        await subscription.cancel();
      }
      if (!mounted) return false;
      setState(() {
        _longitude.text = point.longitude.toStringAsFixed(6);
        _latitude.text = point.latitude.toStringAsFixed(6);
      });
      return true;
    } on RouteApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'GPS 위치를 확인하지 못했어요. 다시 시도하거나 다른 장소를 선택해주세요.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    return false;
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final target = double.tryParse(_target.text.trim());
      if (target == null) {
        throw const RouteApiException('범위 안에서 목표 거리(km)를 입력해주세요.');
      }
      if (!target.isFinite || target < _minTarget || target > _maxTarget) {
        throw const RouteApiException('화면에 표시된 범위 안에서 목표 거리를 선택해주세요.');
      }
      if (!_otherPlace && _longitude.text.isEmpty && _latitude.text.isEmpty) {
        if (!await _useCurrentLocation() || !mounted) return;
      }
      final lon = double.tryParse(_longitude.text.trim());
      final lat = double.tryParse(_latitude.text.trim());
      if (lon == null || lat == null) {
        throw const RouteApiException('검색 결과에서 출발 기준 장소를 선택해주세요.');
      }
      final request = RouteRequest(
        input: _input,
        targetDistanceKm: target,
        longitude: lon,
        latitude: lat,
        options: RouteSearchOptions(
          approachMeters: _range.approachMeters,
          tolerance: _range.tolerance,
        ),
      );
      request.toJson();
      final routes = await _service.generate(request);
      if (!mounted) return;
      // Keep this request locked until the result screen is dismissed.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RouteRecommendationScreen(
            input: _input,
            routes: routes,
            result: routes,
          ),
        ),
      );
    } on RouteApiException catch (error) {
      if (mounted) {
        setState(
          () => _message =
              '${error.message}${error.retryAt == null ? '' : ' 재시도 가능 시각: ${error.retryAt!.toLocal()}'}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '요청을 완료하지 못했습니다. 서버 상태와 설정을 확인해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_locating;
    final previewOnly = widget.service == null && !widget.config.hasToken;
    return Scaffold(
      appBar: AppBar(title: const Text('경로 만들기')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 112,
                child: DrawingPreview(drawing: widget.drawing),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.drawing.strokes.length != 1)
                const Text('경로를 찾으려면 한 획으로 그려주세요.'),
              Text('어디서 달릴까요?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.my_location, size: 18),
                    label: const Text('현재 위치'),
                    selected: !_otherPlace,
                    onSelected: enabled ? (_) => _selectPlaceMode(false) : null,
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.search, size: 18),
                    label: const Text('다른 장소'),
                    selected: _otherPlace,
                    onSelected: enabled ? (_) => _selectPlaceMode(true) : null,
                  ),
                ],
              ),
              if (!_otherPlace)
                Text(
                  _longitude.text.isEmpty
                      ? '경로를 생성할 때 현재 위치를 확인해요.'
                      : '현재 위치를 코스 탐색 기준으로 설정했습니다.',
                )
              else if (_canSearch) ...[
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  key: const Key('place-query'),
                  controller: _query,
                  enabled: enabled && !_searching,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlaces(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: '지역명, 장소 또는 주소',
                    hintText: '예: 평촌중앙공원',
                    suffixIcon: IconButton(
                      tooltip: '장소 검색',
                      onPressed: enabled && !_searching ? _searchPlaces : null,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                if (_searching) const LinearProgressIndicator(),
                if (_searchMessage != null) Text(_searchMessage!),
                for (final place in _places)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place.name),
                    subtitle: place.address == place.name
                        ? null
                        : Text(place.address),
                    onTap: enabled ? () => _setPlace(place) : null,
                  ),
                if (_place case final place?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(place.name),
                    subtitle: place.address == place.name
                        ? null
                        : Text(place.address),
                  ),
              ],
              if (_otherPlace && !_canSearch) ...[
                const Text('장소 검색을 사용할 수 없어요. 출발 위치의 좌표를 입력해주세요.'),
                _coordinateField(
                  'test-longitude',
                  '기준 경도',
                  _longitude,
                  enabled,
                ),
                _coordinateField('test-latitude', '기준 위도', _latitude, enabled),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _target,
                key: const Key('target-distance'),
                enabled: !_busy && !_locating,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '목표 거리 (km)',
                  helperText: _minTarget <= _maxTarget
                      ? '${_minTarget.toStringAsFixed(1)}~${_maxTarget.toStringAsFixed(1)} km 사이에서 선택'
                      : '뒤로 돌아가 8 km 이하를 포함하는 범위를 선택해주세요.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '어디까지 찾아볼까요?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final range in _SearchRange.values)
                    ChoiceChip(
                      label: Text(range.label),
                      selected: _range == range,
                      onSelected: enabled
                          ? (_) => setState(() => _range = range)
                          : null,
                    ),
                ],
              ),
              ValueListenableBuilder(
                valueListenable: _target,
                builder: (context, value, _) {
                  final target = double.tryParse(value.text.trim());
                  final percent = (_range.tolerance * 100).round();
                  final distance =
                      target != null &&
                          target.isFinite &&
                          target >= _minTarget &&
                          target <= _maxTarget
                      ? '약 ${(target * (1 - _range.tolerance)).toStringAsFixed(2)}~${(target * (1 + _range.tolerance)).toStringAsFixed(2)} km'
                      : '목표 거리의 ±$percent%';
                  return Text(
                    '선택한 장소에서 ${_range.approachLabel} 이내에 시작하고, '
                    '길이가 ${distance}인 코스를 찾아요.',
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (previewOnly)
                const Text(
                  'API_TOKEN 설정이 필요합니다. config/app.local.json에 공유 개발 토큰을 설정하고 다시 실행해주세요.',
                ),
              if (_message != null)
                Text(
                  _message!,
                  key: const Key('api-message'),
                  textAlign: TextAlign.center,
                ),
              if (_busy || _locating) ...[
                const LinearProgressIndicator(),
                Text(_locating ? '현재 위치를 확인하고 있어요.' : '그린 모양과 비슷한 코스를 찾고 있어요.'),
              ],
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                onPressed:
                    !enabled ||
                        _searching ||
                        _minTarget > _maxTarget ||
                        widget.drawing.strokes.length != 1 ||
                        previewOnly
                    ? null
                    : () => _request(),
                child: const Text('경로 생성'),
              ),
              if (previewOnly)
                OutlinedButton(
                  onPressed: enabled
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                RouteRecommendationScreen(input: _input),
                          ),
                        )
                      : null,
                  child: const Text('추천 화면 미리보기'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _setPlace(RoutePlace place) {
    setState(() {
      _place = place;
      _places = const [];
      _query.text = place.name;
      _longitude.text = place.longitude.toString();
      _latitude.text = place.latitude.toString();
      _message = null;
    });
  }

  Widget _coordinateField(
    String key,
    String label,
    TextEditingController controller,
    bool enabled,
  ) => TextField(
    key: Key(key),
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    onChanged: (_) {
      if (_place != null) setState(() => _place = null);
    },
  );
}

/// Fits the saved canvas without changing its aspect ratio or stroke data.
class DrawingPreview extends StatelessWidget {
  const DrawingPreview({super.key, required this.drawing});

  final DrawingData drawing;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '그린 모양 미리보기',
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: drawing.canvasSize.isEmpty || !drawing.canvasSize.isFinite
          ? const SizedBox.shrink()
          : FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: drawing.canvasSize,
                  painter: _DrawingPreviewPainter(drawing),
                ),
              ),
            ),
    ),
  );
}

class _DrawingPreviewPainter extends CustomPainter {
  const _DrawingPreviewPainter(this.drawing);

  final DrawingData drawing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(Colors.white, BlendMode.src);
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in drawing.strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          paint.strokeWidth / 2,
          Paint()..color = AppColors.primary,
        );
      } else {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (final point in stroke.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPreviewPainter oldDelegate) =>
      oldDelegate.drawing != drawing;
}
