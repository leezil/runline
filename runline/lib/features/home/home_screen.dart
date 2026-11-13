import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';

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
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE6E9FF),
              child: Icon(Icons.person_outline, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('민지 러너', style: textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('좋은 아침이에요, 러너!', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('오늘의 목표까지 한 걸음 더 달려볼까요?', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFF7A45)),
                  const SizedBox(width: AppSpacing.xs),
                  Text('러닝 목표', style: textTheme.titleMedium),
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
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          onTap: () {},
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('러닝 시작하기', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text('지금 바로 새로운 러닝을 시작하세요.', style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                onPressed: () {},
                icon: Icons.route_outlined,
                label: '루트 그리기',
                variant: AppButtonVariant.outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                onPressed: () {},
                icon: Icons.flag_outlined,
                label: '목표 설정',
                variant: AppButtonVariant.outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
