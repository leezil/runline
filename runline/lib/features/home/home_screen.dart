import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/primary_action_button.dart';
import '../../shared/widgets/stat_metric.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text('좋은 아침이에요, 러너!', style: textTheme.headlineMedium)),
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE6E9FF),
              child: Icon(Icons.person_outline, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('오늘의 목표까지 한 걸음 더 달려볼까요?', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        const AppChip(label: '이번 주', icon: Icons.calendar_today_outlined, selected: true),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFF7A45)),
                  const SizedBox(width: AppSpacing.xs),
                  Text('이번 주 러닝', style: textTheme.titleMedium),
                  const Spacer(),
                  Text('목표 20 km', style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('12.4 km', style: textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: Color(0xFFE6E9FF),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('목표의 62%를 달성했어요.', style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              StatMetric(label: '이번 주 횟수', value: '3', unit: '회'),
              SizedBox(height: 44, child: VerticalDivider()),
              StatMetric(label: '평균 페이스', value: "6'12\"", unit: '/km'),
              SizedBox(height: 44, child: VerticalDivider()),
              StatMetric(label: '누적 시간', value: '1:17', unit: '시간'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('오늘의 러닝', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E9FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_run, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('가볍게 3 km 달리기', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('예상 소요 시간 20분', style: textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.subText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: '러닝 시작하기',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
      ],
    );
  }
}
