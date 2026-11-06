import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_action_button.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: Text('클럽', style: textTheme.headlineMedium)),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '클럽 만들기',
            ),
          ],
        ),
        Text('함께 달릴 러닝 크루를 찾아보세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 112,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Icon(Icons.groups_2_outlined, color: Colors.white, size: 48),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('서울 모닝 러너스', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('멤버 248명 · 초급부터 함께 달려요', style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryActionButton(
                      label: '클럽 둘러보기',
                      icon: Icons.arrow_forward,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('다가오는 러닝', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(
          child: Row(
            children: [
              _DateBadge(),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('토요일 한강 5K', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: AppSpacing.xxs),
                    Text('11월 8일 · 오전 8:00 · 여의도'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.subText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('추천 클럽', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const _ClubListItem(
          name: '퇴근 후 러닝 크루',
          detail: '멤버 126명 · 강남',
          color: Color(0xFFFF8A65),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _ClubListItem(
          name: '주말 트레일 러너스',
          detail: '멤버 89명 · 서울 전역',
          color: Color(0xFF2E9B6C),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFFE6E9FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('SAT', style: TextStyle(fontSize: 10, color: AppColors.primary)),
        Text('8', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _ClubListItem extends StatelessWidget {
  const _ClubListItem({required this.name, required this.detail, required this.color});

  final String name;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(backgroundColor: color, child: const Icon(Icons.groups, color: Colors.white)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
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
