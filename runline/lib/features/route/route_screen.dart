import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/primary_action_button.dart';

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
        const SizedBox(height: AppSpacing.md),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(label: '저장한 루트', selected: true),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '추천 루트'),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '내 주변', icon: Icons.near_me_outlined),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.lg),
        Text('저장한 루트', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const _RouteItem(
          title: '한강 여의도 순환 코스',
          detail: '5.1 km · 평지 · 저장됨',
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _RouteItem(
          title: '남산 둘레길 러닝',
          detail: '4.2 km · 오르막 68 m · 저장됨',
          color: Color(0xFF2E9B6C),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: '새 루트 만들기',
          icon: Icons.add_location_alt_outlined,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _RouteItem extends StatelessWidget {
  const _RouteItem({required this.title, required this.detail, required this.color});

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.route_outlined, color: color),
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
        const Icon(Icons.chevron_right, color: AppColors.subText),
      ],
    ),
  );
}
