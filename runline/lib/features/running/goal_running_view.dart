import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'running_controller.dart';
import 'running_goal.dart';
import 'running_map_sheet.dart';
import 'running_tabs.dart';
import 'running_timer.dart';

class GoalRunningView extends StatefulWidget {
  const GoalRunningView({
    super.key,
    required this.run,
    required this.map,
    required this.gpsStatus,
    required this.loading,
    required this.storageError,
    required this.retryStorage,
    required this.finish,
  });

  final RunningController run;
  final Widget map;
  final Widget gpsStatus;
  final bool loading;
  final bool storageError;
  final VoidCallback? retryStorage;
  final VoidCallback finish;

  @override
  State<GoalRunningView> createState() => _GoalRunningViewState();
}

class _GoalRunningViewState extends State<GoalRunningView> {
  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final active = run.timer.status == RunningStatus.running;
    final distance = (run.measurement.distanceMeters / 1000).toStringAsFixed(2);
    final elapsed = run.timer.formattedElapsed;
    return Scaffold(
      body: SafeArea(
        child: RunningTabs(
          running: _runPage(distance, elapsed, active),
          measurement: run.measurement,
          elapsed: elapsed,
        ),
      ),
    );
  }

  Widget _runPage(String distance, String elapsed, bool active) {
    final ready = widget.run.timer.status == RunningStatus.ready;
    return RunningMapSheet(
      map: widget.map,
      revealDetails: widget.storageError,
      distance: '$distance km',
      elapsed: elapsed,
      pace: widget.run.pace,
      details: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active)
            Text(
              ready ? '러닝 시작 준비' : '러닝 일시정지',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          _progress(),
          const SizedBox(height: AppSpacing.sm),
          widget.gpsStatus,
          if (widget.storageError) _storageMessage(),
        ],
      ),
      actions: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (active)
              _runningAction(
                label: '일시정지',
                icon: Icons.pause_rounded,
                background: AppColors.text,
                onPressed: widget.run.pause,
                onLongPress: widget.finish,
              )
            else ...[
              _runningAction(
                label: '종료',
                icon: Icons.stop_rounded,
                background: AppColors.text,
                onLongPress: widget.loading ? null : widget.finish,
              ),
              _runningAction(
                label: ready ? '다시 시작' : '재개',
                icon: Icons.play_arrow_rounded,
                onPressed: widget.loading || widget.run.preparing
                    ? null
                    : widget.run.startOrResume,
              ),
            ],
          ],
        ),
      ),
      compactActions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: active ? '일시정지' : (ready ? '다시 시작' : '재개'),
            onPressed: active
                ? widget.run.pause
                : widget.loading || widget.run.preparing
                ? null
                : widget.run.startOrResume,
            iconSize: 18,
            icon: Icon(active ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '종료 · 길게 눌러 종료',
            child: FilledButton(
              onPressed: null,
              onLongPress: widget.loading ? null : widget.finish,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                fixedSize: const Size.square(40),
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: const Icon(Icons.stop, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storageMessage() => TextButton(
    onPressed: widget.retryStorage,
    child: const Text('기록 저장 실패 · 다시 시도'),
  );

  Widget _progress() {
    final goal = widget.run.goal!;
    final label = switch (goal) {
      DistanceGoal(:final distanceKm) =>
        '목표 ${distanceKm.toStringAsFixed(2)} km',
      DurationGoal(:final duration) =>
        '목표 ${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
    };
    return Column(
      children: [
        LinearProgressIndicator(
          key: const Key('running-goal-progress'),
          value: widget.run.goalProgress,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, key: const Key('running-goal-label')),
      ],
    );
  }

  Widget _runningAction({
    required String label,
    required IconData icon,
    Color background = AppColors.primary,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Tooltip(
        message: onLongPress == null ? label : '$label · 길게 눌러 종료',
        child: FilledButton.icon(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: FilledButton.styleFrom(backgroundColor: background),
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ),
    ),
  );
}
