import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/stat_metric.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('활동', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('최근 러닝 기록과 통계를 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(label: '이번 주', icon: Icons.calendar_today_outlined, selected: true),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '이번 달'),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '올해'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이번 주 요약', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatMetric(label: '거리', value: '12.4', unit: 'km'),
                  StatMetric(label: '러닝', value: '3', unit: '회'),
                  StatMetric(label: '시간', value: '1:17'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _WeeklyChart(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('최근 활동', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const _ActivityItem(
          date: '오늘',
          title: '아침 한강 러닝',
          detail: '5.2 km · 30:12 · 5\'48" /km',
          icon: Icons.directions_run,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _ActivityItem(
          date: '11월 4일',
          title: '퇴근 후 이지런',
          detail: '4.2 km · 26:18 · 6\'16" /km',
          icon: Icons.nightlight_outlined,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _ActivityItem(
          date: '11월 2일',
          title: '주말 공원 러닝',
          detail: '3.0 km · 18:33 · 6\'11" /km',
          icon: Icons.park_outlined,
        ),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context) {
    const heights = [24.0, 54.0, 34.0, 76.0, 42.0, 16.0, 8.0];
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          labels.length,
          (index) => Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 22,
                height: heights[index],
                decoration: BoxDecoration(
                  color: index == 3 ? AppColors.primary : const Color(0xFFE0E4EE),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(labels[index], style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.date,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String date;
  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE6E9FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(date, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
