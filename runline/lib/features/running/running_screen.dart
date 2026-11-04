import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/runline_map_view.dart';
import 'running_timer.dart';
import 'running_goal.dart';

class RunningScreen extends StatefulWidget {
  const RunningScreen({
    super.key,
    this.createTimer = RunningTimer.new,
    this.goal,
  });

  final RunningTimer Function() createTimer;

  /// The optional goal for this run. Direct START remains a run without a goal.
  final RunningGoal? goal;

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  late final RunningTimer _timer;

  @override
  void initState() {
    super.initState();
    _timer = widget.createTimer();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _finish() {
    _timer.finish();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _timer,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          _timer.status == RunningStatus.paused ? '러닝 일시정지' : '러닝 진행 중',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Semantics(
                  label: '러닝 지도',
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DCE2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const RunlineMapView(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.goal case final goal?) ...[
                    Text(
                      switch (goal) {
                        DistanceGoal(:final distanceKm) =>
                          '목표 ${distanceKm.toStringAsFixed(2)} km',
                        DurationGoal(:final duration) =>
                          '목표 ${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      },
                      key: const Key('running-goal-label'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const _RunningMetric(label: '거리', value: '0.00 km'),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _RunningMetric(
                          label: '시간',
                          value: _timer.formattedElapsed,
                        ),
                      ),
                      const Expanded(
                        child: _RunningMetric(
                          label: '평균 페이스',
                          value: "--'--\"",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _timer.status == RunningStatus.paused
                              ? _timer.resume
                              : _timer.pause,
                          icon: Icon(
                            _timer.status == RunningStatus.paused
                                ? Icons.play_arrow
                                : Icons.pause,
                          ),
                          label: Text(
                            _timer.status == RunningStatus.paused
                                ? '재개'
                                : '일시정지',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.stop),
                          label: const Text('종료'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RunningMetric extends StatelessWidget {
  const _RunningMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xxs),
      Text(value, style: Theme.of(context).textTheme.headlineLarge),
    ],
  );
}
