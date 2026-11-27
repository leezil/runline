import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../feed/widgets/feed_post_card.dart';
import 'club_detail_screens.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text('클럽', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const _ClubCover(size: 76),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('서울 저녁 러너스', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('멤버 24명', style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.subText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '목요일 7시, 서울숲에서 만나요!',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.subText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ClubAction(
                label: '공지',
                icon: Icons.push_pin_outlined,
                onTap: () => _open(context, const ClubNoticesScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ClubAction(
                label: '멤버',
                icon: Icons.groups_outlined,
                onTap: () => _open(context, const ClubMembersScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ClubAction(
                label: '클럽 러닝',
                icon: Icons.directions_run,
                onTap: () => _open(context, const ClubRunningScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ClubAction(
                label: '채팅',
                icon: Icons.chat_bubble_outline,
                onTap: () => _open(context, const ClubChatScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text('다가오는 클럽 러닝', style: textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => _open(context, const ClubRunningScreen()),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('전체보기'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const ClubRunCard(title: '서울숲 저녁 러닝', status: '모집중'),
        const SizedBox(height: AppSpacing.sm),
        const FeedPostCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFFE6E9FF),
                    child: Text(
                      '민',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('민수', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '10월 1일에 서울숲 같이 달리실 분! 저녁 7시 정도가 좋을 것 같네요. 관심있으신 분 있으신가요? 클럽 러닝 올려놓겠습니다. 😊',
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18),
                  SizedBox(width: AppSpacing.xs),
                  Text('10'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClubAction extends StatelessWidget {
  const _ClubAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF1F4FB),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 25),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ClubCover extends StatelessWidget {
  const _ClubCover({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9CC5DC), Color(0xFF668A55), Color(0xFF426A3E)],
          ),
        ),
        child: const Icon(Icons.park, color: Colors.white, size: 38),
      ),
    ),
  );
}
