import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import 'running_controller.dart';
import 'running_goal.dart';
import 'running_measurement.dart';
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
  final _pages = PageController();
  int _page = 0;
  int _splitPointCount = -1;
  List<Duration> _splits = const [];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _showPage(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final active = run.timer.status == RunningStatus.running;
    final distance = (run.measurement.distanceMeters / 1000).toStringAsFixed(2);
    final elapsed = run.timer.formattedElapsed;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  active
                      ? _active(distance, elapsed)
                      : _overview(distance, elapsed),
                  _splitPage(elapsed),
                ],
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('러닝')),
                ButtonSegment(value: 1, label: Text('구간')),
              ],
              selected: {_page},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _showPage(value.single),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _overview(String distance, String elapsed) => Column(
    children: [
      Expanded(flex: 3, child: widget.map),
      Expanded(
        flex: 4,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              widget.run.timer.status == RunningStatus.ready
                  ? '러닝 시작 준비'
                  : '러닝 일시정지',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _metrics([
              ('킬로미터', '$distance km'),
              ('평균 페이스', widget.run.pace),
              ('시간', elapsed),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _metrics(const [('칼로리', '—'), ('고도', '—'), ('BPM', '—')]),
            const SizedBox(height: AppSpacing.md),
            _progress(),
            const SizedBox(height: AppSpacing.sm),
            widget.gpsStatus,
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundAction(
              label: '종료',
              icon: Icons.stop_rounded,
              background: AppColors.text,
              onLongPress: widget.loading ? null : widget.finish,
            ),
            _roundAction(
              label: widget.run.timer.status == RunningStatus.ready
                  ? '다시 시작'
                  : '재개',
              icon: Icons.play_arrow_rounded,
              onPressed: widget.loading || widget.run.preparing
                  ? null
                  : widget.run.startOrResume,
            ),
          ],
        ),
      ),
      if (widget.storageError) _storageMessage(),
    ],
  );

  Widget _active(String distance, String elapsed) {
    final durationGoal = widget.run.goal is DurationGoal;
    return ColoredBox(
      color: const Color(0xFFE5E9FF),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _metrics([
              durationGoal ? ('킬로미터', '$distance km') : ('시간', elapsed),
              ('BPM', '—'),
              ('페이스', widget.run.pace),
            ]),
            Expanded(
              child: Center(
                child: _GoalMetric(
                  label: durationGoal ? '시간' : '킬로미터',
                  value: durationGoal ? elapsed : '$distance km',
                  large: true,
                ),
              ),
            ),
            _progress(),
            widget.gpsStatus,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: _roundAction(
                label: '일시정지',
                icon: Icons.pause_rounded,
                background: AppColors.text,
                onPressed: widget.run.pause,
                onLongPress: widget.finish,
              ),
            ),
            if (widget.storageError) _storageMessage(),
          ],
        ),
      ),
    );
  }

  Widget _storageMessage() => TextButton(
    onPressed: widget.retryStorage,
    child: const Text('기록 저장 실패 · 다시 시도'),
  );

  Widget _metrics(List<(String, String)> values) => Row(
    children: [
      for (final (label, value) in values)
        Expanded(
          child: _GoalMetric(label: label, value: value),
        ),
    ],
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

  Widget _roundAction({
    required String label,
    required IconData icon,
    Color background = AppColors.primary,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FilledButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          minimumSize: const Size.square(72),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      if (onLongPress != null) const Text('길게 눌러 종료'),
    ],
  );

  Widget _splitPage(String elapsed) {
    final measurement = widget.run.measurement;
    if (_splitPointCount != measurement.pointCount) {
      _splitPointCount = measurement.pointCount;
      _splits = _buildSplits(measurement);
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('구간 페이스', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          _splitRow('킬로미터', '페이스', '편차'),
          const Divider(),
          Expanded(
            child: _splits.isEmpty
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: Text('1km를 완료하면 구간 페이스가 표시됩니다.'),
                  )
                : ListView.builder(
                    itemCount: _splits.length,
                    itemBuilder: (context, index) {
                      final pace = _splits[index];
                      final difference = index == 0
                          ? '—'
                          : _formatDifference(pace - _splits[index - 1]);
                      return _splitRow(
                        '${index + 1}',
                        _formatPace(pace),
                        difference,
                      );
                    },
                  ),
          ),
          Center(
            child: FilledButton.icon(
              onPressed: () => _showPage(0),
              icon: const Icon(Icons.arrow_back),
              label: Text(elapsed),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _splitRow(String kilometer, String pace, String difference) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  child: Row(
    children: [
      Expanded(child: Text(kilometer)),
      Expanded(child: Text(pace, textAlign: TextAlign.center)),
      Expanded(child: Text(difference, textAlign: TextAlign.end)),
    ],
  ),
);

String _formatPace(Duration pace) =>
    "${pace.inMinutes}'${(pace.inSeconds % 60).toString().padLeft(2, '0')}\"";

String _formatDifference(Duration difference) {
  final seconds = (difference.inMilliseconds / 1000).round();
  if (seconds == 0) return '0초';
  return '${seconds > 0 ? '+' : '−'}${seconds.abs()}초';
}

List<Duration> _buildSplits(RunningMeasurement measurement) {
  final points = measurement.points;
  final starts = measurement.segmentStarts.toSet();
  final result = <Duration>[];
  var meters = 0.0;
  var microseconds = 0.0;
  for (var i = 1; i < points.length; i++) {
    if (starts.contains(i)) continue;
    final distance = RunningMeasurement.surfaceDistance(
      points[i - 1],
      points[i],
    );
    if (distance <= 0) continue;
    final elapsed = points[i].timestamp.difference(points[i - 1].timestamp);
    if (elapsed <= Duration.zero) continue;
    final microsPerMeter = elapsed.inMicroseconds / distance;
    var remaining = distance;
    while (meters + remaining >= 1000) {
      final needed = 1000 - meters;
      microseconds += needed * microsPerMeter;
      result.add(Duration(microseconds: microseconds.round()));
      remaining -= needed;
      meters = 0;
      microseconds = 0;
    }
    meters += remaining;
    microseconds += remaining * microsPerMeter;
  }
  return result;
}

class _GoalMetric extends StatelessWidget {
  const _GoalMetric({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: TextStyle(
            color: AppColors.text,
            fontSize: large ? 76 : 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}
