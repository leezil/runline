import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('내 루트', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('저장한 러닝 루트와 코스를 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          label: '테스트용 지도 영역',
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFD9DCE2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 40, color: AppColors.subText),
                  const SizedBox(height: AppSpacing.xs),
                  Text('테스트용 지도 영역', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('지도 SDK 연결 전 미리보기', style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppCard(
          child: Row(
            children: [
              Icon(Icons.bookmark_border),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('저장된 루트를 선택해 러닝을 시작하세요.')),
            ],
          ),
        ),
      ],
    );
  }
}
