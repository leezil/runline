import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'feed_detail_screens.dart';
import 'widgets/feed_post.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE6E9FF),
              child: Icon(Icons.person_outline, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('러닝 일상을 공유해보세요.', style: textTheme.titleMedium?.copyWith(color: AppColors.subText)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline), color: AppColors.subText, tooltip: '사진 추가'),
            FilledButton(onPressed: () {}, child: const Text('게시')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FeedPost(
          runnerName: '민수',
          initial: '민',
          timeAgo: '1시간 전',
          title: '오늘은 별 하나를 달렸어요 ⭐',
          distance: '5.2',
          pace: '',
          duration: '32분',
          likes: 56,
          comments: 8,
          mediaType: FeedPostMediaType.routeMap,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FeedPostDetailScreen(
                name: '민수',
                initial: '민',
                text: '오늘은 별 하나를 달렸어요 ⭐',
                likes: 56,
                comments: 8,
                isPhoto: false,
              ),
            ),
          ),
          onProfileTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FeedProfileScreen(name: '민수', initial: '민')),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FeedPost(
          runnerName: '서연',
          initial: '서',
          timeAgo: '5시간 전',
          title: '가을 한강은 언제나 좋아요 🍂',
          distance: '4.8',
          pace: '',
          duration: '28분',
          likes: 32,
          comments: 2,
          avatarColor: Color(0xFF8C7C61),
          mediaType: FeedPostMediaType.runningPhoto,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FeedPostDetailScreen(
                name: '서연',
                initial: '서',
                text: '가을 한강은 언제나 좋아요 🍂',
                likes: 32,
                comments: 2,
                isPhoto: true,
              ),
            ),
          ),
          onProfileTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FeedProfileScreen(name: '서연', initial: '서')),
          ),
        ),
      ],
    );
  }
}
