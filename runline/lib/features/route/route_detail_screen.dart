import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/test_map_placeholder.dart';

class RouteDetailScreen extends StatelessWidget {
  const RouteDetailScreen({
    super.key,
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.pace,
  });

  final String title;
  final String date;
  final String distance;
  final String duration;
  final String pace;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String date,
    required String distance,
    required String duration,
    required String pace,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '루트 상세 닫기',
    barrierColor: Colors.transparent,
    pageBuilder: (_, _, _) => RouteDetailScreen(
      title: title,
      date: date,
      distance: distance,
      duration: duration,
      pace: pace,
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: ColoredBox(color: Colors.black.withValues(alpha: .18)),
        ),
      ),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _RouteDetailCard(
                    title: title,
                    date: date,
                    distance: distance,
                    duration: duration,
                    pace: pace,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _RouteDetailCard extends StatelessWidget {
  const _RouteDetailCard({
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.pace,
  });

  final String title;
  final String date;
  final String distance;
  final String duration;
  final String pace;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const TestMapPlaceholder(height: 220, borderRadius: 14),
        const SizedBox(height: AppSpacing.md),
        Text(title, textAlign: TextAlign.center, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$date · 오후 7:00',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _RouteStat(label: '거리', value: distance)),
            Expanded(child: _RouteStat(label: '시간', value: duration)),
            Expanded(child: _RouteStat(label: '페이스', value: pace)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '피드에 공유하기',
          icon: Icons.ios_share_outlined,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('피드 공유 화면은 준비 중입니다.')),
          ),
          variant: AppButtonVariant.outlined,
        ),
      ],
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xxs),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        ),
      ),
    ],
  );
}
