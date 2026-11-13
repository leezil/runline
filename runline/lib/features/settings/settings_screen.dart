import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_label_action.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '닫기',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFFE6E9FF),
                child: Icon(Icons.person_outline, size: 44, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: Text('민지 러너', style: textTheme.headlineMedium)),
            const SizedBox(height: AppSpacing.xxs),
            Center(child: Text('runline@runner.com', style: textTheme.bodySmall)),
            const SizedBox(height: AppSpacing.xxl),
            Text('설정', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: SizedBox(
                height: 196,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisExtent: 92,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.xs,
                  children: [
                    IconLabelAction(
                      label: '프로필 편집',
                      icon: Icons.edit_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '도전 과제',
                      icon: Icons.emoji_events_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '개인정보 관리',
                      icon: Icons.privacy_tip_outlined,
                      onPressed: () {},
                    ),
                    IconLabelAction(
                      label: '알림 설정',
                      icon: Icons.notifications_outlined,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
