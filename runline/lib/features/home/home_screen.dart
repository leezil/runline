import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/app_card.dart';
import '../route_drawing/route_drawing_screen.dart';
import '../running/running_screen.dart';
import '../running/running_goal.dart';
import '../running/history/running_record_detail_screen.dart';
import '../running/history/running_history_repository.dart';
import 'running_goal_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _weeklyGoalKm = 20;
  late Future<double> _weeklyDistance;

  @override
  void initState() {
    super.initState();
    _loadWeeklyDistance();
    RunningHistory.completedRuns.addListener(_refreshWeeklyDistance);
  }

  @override
  void dispose() {
    RunningHistory.completedRuns.removeListener(_refreshWeeklyDistance);
    super.dispose();
  }

  void _refreshWeeklyDistance() => setState(_loadWeeklyDistance);

  void _loadWeeklyDistance() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    _weeklyDistance = RunningHistory.open()
        .then((repository) => repository.list(finished: true))
        .then((records) {
          var meters = 0.0;
          for (final record in records) {
            final start = record.startedAt.toLocal();
            if (!start.isBefore(monday) && start.isBefore(nextMonday)) {
              meters += record.distanceMeters;
            }
          }
          return meters / 1000;
        });
  }

  Future<void> _setGoal(BuildContext context) async {
    final goal = await showDialog<RunningGoal>(
      context: context,
      builder: (_) => const RunningGoalDialog(),
    );
    if (!context.mounted || goal == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(
          name: RunningScreen.homeStartRunningRoute,
        ),
        builder: (_) => RunningScreen(goal: goal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text('좋은 아침이에요, 러너!', style: textTheme.headlineMedium),
              ),
              IconButton(
                tooltip: '설정',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE6E9FF),
                  child: Icon(Icons.person_outline, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('오늘의 목표까지 한 걸음 더 달려볼까요?', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<double>(
            future: _weeklyDistance,
            builder: (context, snapshot) {
              final distance = snapshot.data;
              final progressLabel = switch (distance) {
                final double km =>
                  '목표의 ${(km / _weeklyGoalKm * 100).round()}%를 달성했어요.',
                null when snapshot.hasError => '러닝 기록을 불러오지 못했습니다.',
                null => '러닝 기록을 불러오는 중입니다.',
              };
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_outlined,
                          color: Color(0xFFFF7A45),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('러닝 목표', style: textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '목표 $_weeklyGoalKm km',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      distance == null
                          ? '— km'
                          : '${distance.toStringAsFixed(2)} km',
                      style: textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: distance == null
                            ? 0
                            : (distance / _weeklyGoalKm).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: AppColors.primary,
                        backgroundColor: Color(0xFFE6E9FF),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(progressLabel, style: textTheme.bodySmall),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: ElevatedButton(
              key: const Key('home-start-button'),
              style: _circleButtonStyle(220, elevation: 4),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RunningScreen()),
              ),
              child: const Text(
                'START',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HomeCircleAction(
                    icon: Icons.edit_outlined,
                    label: '루트 그리기',
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        settings: const RouteSettings(
                          name: RouteDrawingScreen.routeName,
                        ),
                        builder: (_) => const RouteDrawingScreen(),
                      ),
                    ),
                  ),
                  _HomeCircleAction(
                    icon: Icons.flag_outlined,
                    label: '목표 설정',
                    onPressed: () => _setGoal(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
        ],
      ),
    );
  }
}

ButtonStyle _circleButtonStyle(double diameter, {required double elevation}) =>
    ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      minimumSize: Size.square(diameter),
      fixedSize: Size.square(diameter),
      padding: EdgeInsets.zero,
      elevation: elevation,
    );

class _HomeCircleAction extends StatelessWidget {
  const _HomeCircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onPressed,
    style: _circleButtonStyle(72, elevation: 2),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
