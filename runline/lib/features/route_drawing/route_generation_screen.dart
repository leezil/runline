import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'drawing_controller.dart';
import '../route_generation/route_api.dart';
import '../route_generation/route_search_settings.dart';
import '../route_recommendation/recommended_route.dart';
import '../route_recommendation/route_recommendation_screen.dart';

class RouteGenerationScreen extends StatefulWidget {
  const RouteGenerationScreen({
    super.key,
    required this.drawing,
    this.minDistanceKm = 4,
    this.maxDistanceKm = 8,
    this.service,
    this.config = const RouteApiConfig(),
  });

  final DrawingData drawing;
  final double minDistanceKm;
  final double maxDistanceKm;
  final RouteService? service;
  final RouteApiConfig config;

  @override
  State<RouteGenerationScreen> createState() => _RouteGenerationScreenState();
}

class _RouteGenerationScreenState extends State<RouteGenerationScreen> {
  final _target = TextEditingController();
  final _longitude = TextEditingController();
  final _latitude = TextEditingController();
  final _settings = RouteSearchSettingsController();
  late final RouteService _service =
      widget.service ?? RouteApi(config: widget.config);
  bool _busy = false;
  String? _message;
  RouteGenerationInput get _input => RouteGenerationInput(
    drawing: widget.drawing,
    minDistanceKm: widget.minDistanceKm,
    maxDistanceKm: widget.maxDistanceKm,
  );

  @override
  void dispose() {
    _target.dispose();
    _longitude.dispose();
    _latitude.dispose();
    _settings.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _request({bool health = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (health) {
        await _service.health();
        if (mounted) {
          setState(() => _message = '서버 상태 확인 성공 · 경로 생성 인증 성공을 의미하지 않습니다.');
        }
      } else {
        final target = double.tryParse(_target.text.trim());
        final lon = double.tryParse(_longitude.text.trim());
        final lat = double.tryParse(_latitude.text.trim());
        if (target == null) {
          throw const RouteApiException('거리 범위 안에서 사용할 목표 거리(km)를 직접 입력해주세요.');
        }
        if (lon == null || lat == null) {
          throw const RouteApiException(
            '개발 테스트용 기준 위치(경도·위도)를 입력해주세요. 현재 GPS 위치는 사용하지 않습니다.',
          );
        }
        final request = RouteRequest(
          input: _input,
          targetDistanceKm: target,
          longitude: lon,
          latitude: lat,
          options: _settings.read(),
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
      }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('경로 만들기')),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 300,
              child: DrawingPreview(drawing: widget.drawing),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('그린 모양을 바탕으로 러닝 경로를 생성할 준비가 되었습니다.'),
            const SizedBox(height: AppSpacing.xs),
            Text('전체 point 개수: ${widget.drawing.points.length}개'),
            Text(
              '캔버스: ${widget.drawing.canvasSize.width.toStringAsFixed(0)} × ${widget.drawing.canvasSize.height.toStringAsFixed(0)} · ${widget.drawing.strokes.length}획',
            ),
            const Text('API v1은 한 획 그림만 지원합니다. 여러 획은 뒤로 돌아가 초기화 후 다시 그려주세요.'),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '선택한 거리 범위: ${widget.minDistanceKm}–${widget.maxDistanceKm} km',
            ),
            const Text('서버 지원 목표 거리: 0.3~8 km. 선택 범위와 겹치는 거리만 요청할 수 있습니다.'),
            TextField(
              controller: _target,
              key: const Key('target-distance'),
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '목표 거리 (km)',
                helperText: '범위 안에서 사용할 단일 목표 거리를 직접 입력하세요.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('개발 테스트용 기준 위치 · 현재 GPS 위치가 아닙니다.'),
            TextField(
              controller: _longitude,
              key: const Key('test-longitude'),
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '테스트 경도 (124~132)'),
            ),
            TextField(
              controller: _latitude,
              key: const Key('test-latitude'),
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: '테스트 위도 (32~39)'),
            ),
            RouteSearchSettings(controller: _settings, enabled: !_busy),
            if (widget.service == null && !widget.config.hasToken)
              const Text(
                'ROUTE_API_TOKEN 설정이 필요합니다. config/route-api.local.json에 공유 개발 토큰을 설정하고 다시 실행해주세요.',
              ),
            const Text(
              'Flutter Web 토큰은 브라우저에서 확인 가능합니다. 공유 테스트 토큰을 쓰는 개발 환경에서만 직접 호출하세요.',
            ),
            if (_message != null)
              Text(_message!, key: const Key('api-message')),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const Text('요청 중입니다. 화면을 나가거나 120초가 지나도 서버 계산은 계속될 수 있습니다.'),
            ],
            OutlinedButton(
              onPressed: _busy ? null : () => _request(health: true),
              child: const Text('서버 상태 확인'),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed:
                  _busy || (widget.service == null && !widget.config.hasToken)
                  ? null
                  : () => _request(),
              child: const Text('경로 생성'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('개발용 미리보기: Mock Data를 사용하며 실제 추천 경로가 아닙니다.'),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            RouteRecommendationScreen(input: _input),
                      ),
                    ),
              child: const Text('추천 화면 미리보기'),
            ),
          ],
        ),
      ),
    ),
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
