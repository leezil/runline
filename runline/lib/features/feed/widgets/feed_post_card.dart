import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../app/app_spacing.dart';

/// Shared surface and tap behavior for feed posts shown in timelines and previews.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    ),
  );
}
