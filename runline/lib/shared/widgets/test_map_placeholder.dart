import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';

class TestMapPlaceholder extends StatelessWidget {
  const TestMapPlaceholder({super.key, this.height, this.borderRadius = 20});

  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '테스트용 지도 영역',
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD9DCE2),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40, color: AppColors.subText),
            const SizedBox(height: AppSpacing.xs),
            Text('테스트용 지도 영역', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text('지도 SDK 연결 전 미리보기', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
