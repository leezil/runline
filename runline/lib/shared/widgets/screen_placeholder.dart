import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import 'app_card.dart';

class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(title, style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(description, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text('화면 콘텐츠 영역', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text('이 카드에 실제 데이터와 UI를 추가하세요.', style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
