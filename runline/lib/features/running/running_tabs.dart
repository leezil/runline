import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import 'running_measurement.dart';

class RunningTabs extends StatefulWidget {
  const RunningTabs({
    super.key,
    required this.running,
    required this.measurement,
    required this.elapsed,
  });

  final Widget running;
  final RunningMeasurement measurement;
  final String elapsed;

  @override
  State<RunningTabs> createState() => _RunningTabsState();
}

class _RunningTabsState extends State<RunningTabs> {
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
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (page) => setState(() => _page = page),
            children: [widget.running, _splitPage(widget.elapsed)],
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
    );
  }

  Widget _splitPage(String elapsed) {
    final measurement = widget.measurement;
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
