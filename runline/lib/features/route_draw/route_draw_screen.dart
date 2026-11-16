import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';

class RouteDrawScreen extends StatefulWidget {
  const RouteDrawScreen({super.key});

  @override
  State<RouteDrawScreen> createState() => _RouteDrawScreenState();
}

class _RouteDrawScreenState extends State<RouteDrawScreen> {
  final List<Offset?> _points = [];
  RangeValues _distanceRange = const RangeValues(4, 8);
  int _selectedShape = 0;

  void _addPoint(Offset point) => setState(() => _points.add(point));

  void _endLine() => setState(() => _points.add(null));

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '닫기',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('달리고 싶은 그림을 그려보세요!', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: GestureDetector(
                  onPanStart: (details) => _addPoint(details.localPosition),
                  onPanUpdate: (details) => _addPoint(details.localPosition),
                  onPanEnd: (_) => _endLine(),
                  child: CustomPaint(
                    painter: _SketchPainter(points: _points, fallbackShape: _selectedShape),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6FD),
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('추천 모양', style: textTheme.titleMedium),
                const Spacer(),
                Text('옆으로 드래그', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _shapeOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => _ShapeOption(
                  option: _shapeOptions[index],
                  selected: _selectedShape == index,
                  onTap: () => setState(() {
                    _selectedShape = index;
                    _points.clear();
                  }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('거리 범위', style: textTheme.titleMedium),
                      const Spacer(),
                      Text('${_distanceRange.start.round()}-${_distanceRange.end.round()} km', style: textTheme.titleMedium),
                    ],
                  ),
                  RangeSlider(
                    values: _distanceRange,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    labels: RangeLabels('${_distanceRange.start.round()} km', '${_distanceRange.end.round()} km'),
                    onChanged: (value) => setState(() => _distanceRange = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: '그림 찾기',
              icon: Icons.search,
              size: AppButtonSize.large,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RouteRecommendationsScreen(
                    distanceRange: _distanceRange,
                    shapeName: _shapeOptions[_selectedShape].name,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteRecommendationsScreen extends StatelessWidget {
  const RouteRecommendationsScreen({super.key, required this.distanceRange, required this.shapeName});

  final RangeValues distanceRange;
  final String shapeName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '닫기',
              ),
            ),
            Text('달리고 싶은 그림을 선택하세요!', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 276,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E5EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.map_outlined, size: 64, color: AppColors.subText)),
            ),
            const SizedBox(height: AppSpacing.md),
            _RecommendationCard(title: '추천 1', detail: '$shapeName · ${distanceRange.start.round()}-${distanceRange.end.round()} km'),
            const SizedBox(height: AppSpacing.sm),
            _RecommendationCard(title: '추천 2', detail: '주변 인기 루트 · 약 ${distanceRange.end.round()} km'),
            const SizedBox(height: AppSpacing.sm),
            _RecommendationCard(title: '추천 3', detail: '평지 위주 · 약 ${distanceRange.start.round()} km'),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: '러닝 시작', icon: Icons.play_arrow_rounded, size: AppButtonSize.large, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () {},
    child: SizedBox(
      height: 70,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
}

class _SuggestedShape {
  const _SuggestedShape(this.name, this.icon);
  final String name;
  final IconData icon;
}

const _shapeOptions = [
  _SuggestedShape('별', Icons.star_border_rounded),
  _SuggestedShape('하트', Icons.favorite_border_rounded),
  _SuggestedShape('달', Icons.nightlight_round),
  _SuggestedShape('번개', Icons.bolt_rounded),
  _SuggestedShape('꽃', Icons.local_florist_outlined),
  _SuggestedShape('물방울', Icons.water_drop_outlined),
];

class _ShapeOption extends StatelessWidget {
  const _ShapeOption({required this.option, required this.selected, required this.onTap});
  final _SuggestedShape option;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${option.name} 추천 모양',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 88,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C98F5) : const Color(0xFFE6E9FF),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withValues(alpha: selected ? 1 : .35)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(option.icon, color: selected ? Colors.white : AppColors.primary, size: 34),
          const SizedBox(height: AppSpacing.xxs),
          Text(option.name, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? Colors.white : AppColors.text)),
        ]),
      ),
    ),
  );
}

class _SketchPainter extends CustomPainter {
  const _SketchPainter({required this.points, required this.fallbackShape});
  final List<Offset?> points;
  final int fallbackShape;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.text..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    if (points.whereType<Offset>().isNotEmpty) {
      Path? path;
      for (final point in points) {
        if (point == null) { if (path != null) canvas.drawPath(path, paint); path = null; }
        else { path ??= Path()..moveTo(point.dx, point.dy); path.lineTo(point.dx, point.dy); }
      }
      if (path != null) canvas.drawPath(path, paint);
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .28;
    if (fallbackShape == 0) {
      final path = Path();
      for (var i = 0; i < 10; i++) { final a = -math.pi / 2 + i * math.pi / 5; final r = i.isEven ? radius : radius * .45; final p = center + Offset(r * math.cos(a), r * math.sin(a)); i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path..close(), paint);
    } else { canvas.drawCircle(center, radius, paint); }
  }
  @override
  bool shouldRepaint(covariant _SketchPainter old) => true;
}

