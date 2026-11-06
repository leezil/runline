import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/widgets/app_chip.dart';
import 'widgets/feed_post.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('피드', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('러너들의 새로운 활동을 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(label: '전체', selected: true),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '팔로잉'),
              SizedBox(width: AppSpacing.xs),
              AppChip(label: '내 클럽'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const FeedPost(
          runnerName: '민지 러너',
          initial: '민',
          timeAgo: '32분 전',
          title: '아침 한강 러닝 완료!',
          distance: '5.2',
          pace: "5'48\"",
          duration: '30:12',
          likes: 24,
          comments: 4,
        ),
        const SizedBox(height: AppSpacing.md),
        const FeedPost(
          runnerName: '준호',
          initial: '준',
          timeAgo: '1시간 전',
          title: '비 오기 전 가볍게 3 km',
          distance: '3.0',
          pace: "6'11\"",
          duration: '18:33',
          likes: 12,
          comments: 2,
          avatarColor: Color(0xFF2E9B6C),
        ),
      ],
    );
  }
}
