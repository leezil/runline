import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../route_drawing/route_drawing_screen.dart';
import '../running/running_screen.dart';
import '../running/running_goal.dart';
import '../running/history/running_record_detail_screen.dart';
import 'running_goal_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _setGoal(BuildContext context) async {
    final goal = await showDialog<RunningGoal>(
      context: context,
      builder: (_) => const RunningGoalDialog(),
    );
    if (!context.mounted || goal == null) return;
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => RunningScreen(goal: goal)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        key: const Key('home-content'),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    label: '프로필 이미지 자리',
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '지현',
                          style: textTheme.titleMedium?.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text('오늘도, 좋은 하루예요!', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const IconButton(
                    onPressed: null,
                    tooltip: '설정',
                    icon: Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('오늘은 어떤 길을 달릴까요?', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                key: const Key('weekly-goal-card'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이번 주 목표', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '12.5 / 20 km',
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        Text(
                          '62%',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const LinearProgressIndicator(
                      value: 0.62,
                      minHeight: 8,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                      semanticsLabel: '이번 주 목표 진행률',
                      semanticsValue: '62%',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: SizedBox.square(
                  dimension: 220,
                  child: ElevatedButton(
                    key: const Key('home-start-button'),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const RunningScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 42),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'START',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('자유 러닝', textAlign: TextAlign.center),
              TextButton.icon(
                key: const Key('home-running-history'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const RunningHistoryListScreen(),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('러닝 기록'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _HomeAction(
                      icon: Icons.draw_outlined,
                      label: '루트그리기',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const RouteDrawingScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _HomeAction(
                      icon: Icons.flag_outlined,
                      label: '목표 설정',
                      onTap: () => _setGoal(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    ),
  );
}
