import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/test_map_placeholder.dart';
import 'route_detail_screen.dart';
import '../../shared/widgets/runline_map_view.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  DateTime _selectedDate = DateTime.now();
  String _sortOrder = '최근 저장순';

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (mounted && pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text('내 루트', style: textTheme.headlineMedium)),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search),
              tooltip: '루트 검색',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('저장한 러닝 루트와 코스를 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFD9DCE2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const RunlineMapView(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortOrder,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: const [
                    DropdownMenuItem(value: '최근 저장순', child: Text('최근 저장순')),
                    DropdownMenuItem(value: '거리순', child: Text('거리순')),
                    DropdownMenuItem(value: '이름순', child: Text('이름순')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortOrder = value);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('저장한 루트', style: textTheme.titleMedium),
        Text('예시 루트 미리보기', style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          mainAxisExtent: 230,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _RouteItem(
              title: '한강 여의도 순환 코스',
              runDate: '2026.09.21',
              runType: '자유 러닝',
              color: AppColors.primary,
              date: '2026.09.21',
              distance: '5.1km',
              duration: '32:40',
              pace: "6'24\"",
            ),
            _RouteItem(
              title: '남산 둘레길 러닝',
              runDate: '2026.09.16',
              runType: '그림 러닝',
              color: Color(0xFF2E9B6C),
              date: '2026.09.16',
              distance: '4.2km',
              duration: '30:18',
              pace: "7'13\"",
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({
    required this.title,
    required this.runDate,
    required this.runType,
    required this.color,
    required this.date,
    required this.distance,
    required this.duration,
    required this.pace,
  });

  final String title;
  final String runDate;
  final String runType;
  final Color color;
  final String date;
  final String distance;
  final String duration;
  final String pace;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => RouteDetailScreen.show(
      context,
      title: title,
      date: date,
      distance: distance,
      duration: duration,
      pace: pace,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$title 지도 미리보기',
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E5EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 44,
                  color: AppColors.subText,
                ),
                Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.route_outlined, size: 18, color: color),
                  ),
                ),
                Positioned(
                  left: 44,
                  top: 34,
                  child: Icon(Icons.location_on, size: 24, color: color),
                ),
                Positioned(
                  right: 48,
                  bottom: 28,
                  child: Icon(Icons.flag, size: 22, color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text('$runDate · $runType', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(distance, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
