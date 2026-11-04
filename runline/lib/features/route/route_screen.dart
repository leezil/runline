import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/runline_map_view.dart';

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
          label: '연동 검증용 카카오맵',
          child: Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFD9DCE2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            // Temporary integration check, not the final saved-route UI.
            child: const RunlineMapView(),
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
