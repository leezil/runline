import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../app/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_metric.dart';

class FeedPost extends StatelessWidget {
  const FeedPost({
    super.key,
    required this.runnerName,
    required this.initial,
    required this.timeAgo,
    required this.title,
    required this.distance,
    required this.pace,
    required this.duration,
    this.likes = 0,
    this.comments = 0,
    this.avatarColor = AppColors.primary,
  });

  final String runnerName;
  final String initial;
  final String timeAgo;
  final String title;
  final String distance;
  final String pace;
  final String duration;
  final int likes;
  final int comments;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor,
                child: Text(
                  initial,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(runnerName, style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(timeAgo, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.subText),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 112,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAEE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.route_outlined, size: 36, color: AppColors.subText),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatMetric(label: '거리', value: distance, unit: 'km'),
              StatMetric(label: '페이스', value: pace, unit: '/km'),
              StatMetric(label: '시간', value: duration),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 20, color: AppColors.subText),
              const SizedBox(width: AppSpacing.xxs),
              Text('$likes', style: textTheme.bodySmall),
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.subText),
              const SizedBox(width: AppSpacing.xxs),
              Text('$comments', style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
