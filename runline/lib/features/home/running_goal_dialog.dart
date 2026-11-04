import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../running/running_goal.dart';

enum _GoalType { distance, duration }

/// Both drafts stay local until START returns only the selected goal.
class RunningGoalDialog extends StatefulWidget {
  const RunningGoalDialog({super.key});

  @override
  State<RunningGoalDialog> createState() => _RunningGoalDialogState();
}

class _RunningGoalDialogState extends State<RunningGoalDialog> {
  _GoalType _type = _GoalType.distance;
  double targetDistanceKm = 7.0;
  Duration targetDuration = const Duration(minutes: 30);

  bool get _isDistance => _type == _GoalType.distance;
  double get _value =>
      _isDistance ? targetDistanceKm : targetDuration.inMinutes.toDouble();
  double get _minimum => _isDistance ? 0.5 : 5;
  double get _maximum => _isDistance ? 50 : 300;
  double get _step => _isDistance ? 0.5 : 5;
  String get _formattedValue => _isDistance
      ? '${targetDistanceKm.toStringAsFixed(2)} Km'
      : '${targetDuration.inMinutes}분';

  void _setValue(double value) => setState(() {
    if (_isDistance) {
      targetDistanceKm = (value * 2).round() / 2;
    } else {
      targetDuration = Duration(minutes: (value / 5).round() * 5);
    }
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.md),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '오늘의 목표',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _formattedValue,
              key: const Key('target-goal-value'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontSize: 44, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: _isDistance ? '목표 거리 줄이기' : '목표 시간 줄이기',
                  onPressed: _value > _minimum
                      ? () => _setValue(_value - _step)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Slider(
                    value: _value,
                    min: _minimum,
                    max: _maximum,
                    divisions: _isDistance ? 99 : 59,
                    label: _formattedValue,
                    semanticFormatterCallback: (value) => _isDistance
                        ? '${value.toStringAsFixed(2)} 킬로미터'
                        : '${value.round()}분',
                    onChanged: _setValue,
                  ),
                ),
                IconButton.outlined(
                  tooltip: _isDistance ? '목표 거리 늘리기' : '목표 시간 늘리기',
                  onPressed: _value < _maximum
                      ? () => _setValue(_value + _step)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isDistance ? '0.5~50km · 0.5km 단위' : '5분~5시간 · 5분 단위',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                PopupMenuButton<_GoalType>(
                  key: const Key('goal-type-menu'),
                  tooltip: '목표 종류 선택',
                  initialValue: _type,
                  onSelected: (type) => setState(() => _type = type),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _GoalType.distance, child: Text('거리')),
                    PopupMenuItem(value: _GoalType.duration, child: Text('시간')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_isDistance ? '거리' : '시간'),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const Key('target-start-button'),
                  onPressed: () => Navigator.of(context).pop<RunningGoal>(
                    _isDistance
                        ? RunningGoal.distance(targetDistanceKm)
                        : RunningGoal.duration(targetDuration),
                  ),
                  child: const Text('START'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
