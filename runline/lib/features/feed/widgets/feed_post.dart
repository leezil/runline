import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../app/app_spacing.dart';
import '../../../shared/widgets/test_map_placeholder.dart';

enum FeedPostMediaType { routeMap, runningPhoto }

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
    this.mediaType = FeedPostMediaType.routeMap,
    this.onTap,
    this.onProfileTap,
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
  final FeedPostMediaType mediaType;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(99),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 194,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: mediaType == FeedPostMediaType.routeMap
                  ? const TestMapPlaceholder(borderRadius: 14)
                  : const _RunningPhotoPreview(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('$distance km · $duration', style: textTheme.bodyMedium?.copyWith(color: AppColors.subText)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.favorite, size: 22, color: mediaType == FeedPostMediaType.routeMap ? const Color(0xFFD6556D) : AppColors.subText),
              const SizedBox(width: AppSpacing.xxs),
              Text('$likes', style: textTheme.bodyMedium),
              const SizedBox(width: AppSpacing.md),
              const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.subText),
              const SizedBox(width: AppSpacing.xxs),
              Text('$comments', style: textTheme.bodyMedium),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: AppColors.subText),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _RunningPhotoPreview extends StatelessWidget {
  const _RunningPhotoPreview();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RunningPhotoPainter(),
    child: const ColoredBox(color: Color(0xFFD8E0EC)),
  );
}

class _RunningPhotoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * .48), Paint()..color = const Color(0xFFB9CEE2));
    canvas.drawRect(Rect.fromLTWH(0, size.height * .48, size.width, size.height * .52), Paint()..color = const Color(0xFF92B66A));
    canvas.drawPath(Path()..moveTo(0, size.height)..lineTo(size.width * .45, size.height * .46)..lineTo(size.width * .78, size.height * .46)..lineTo(size.width, size.height)..close(), Paint()..color = const Color(0xFFE6DFD0));
    final building = Paint()..color = const Color(0xFF7A8790);
    for (var i = 0; i < 7; i++) { canvas.drawRect(Rect.fromLTWH(i * 35.0, size.height * .25 - (i % 3) * 9, 25, 42 + (i % 3) * 9), building); }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

