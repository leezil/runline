import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('오늘도 달려볼까요?', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('러닝을 시작하면 기록이 여기에 쌓입니다.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            children: [
              Icon(
                Icons.play_circle_fill,
                color: Theme.of(context).colorScheme.primary,
                size: 72,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('START', style: textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text('새 러닝을 시작하세요', style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
