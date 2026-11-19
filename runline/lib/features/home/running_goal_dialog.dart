import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../running/running_goal.dart';

enum _GoalType { distance, duration }

/// Both drafts stay local until the start action returns only the selected goal.
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
  String get _displayValue {
    if (_isDistance) return targetDistanceKm.toStringAsFixed(2);
    final hours = targetDuration.inHours.toString().padLeft(2, '0');
    final minutes = (targetDuration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String get _formattedValue => _isDistance
      ? '${targetDistanceKm.toStringAsFixed(2)} km'
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
            Center(
              child: SegmentedButton<_GoalType>(
                segments: const [
                  ButtonSegment(value: _GoalType.distance, label: Text('거리')),
                  ButtonSegment(value: _GoalType.duration, label: Text('시간')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.single),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Semantics(
                  label: _formattedValue,
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _displayValue,
                          key: const Key('target-goal-value'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_isDistance ? '킬로미터' : '시간 · 분'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
            Center(
              child: FilledButton(
                key: const Key('target-start-button'),
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: const Size.square(92),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                ),
                onPressed: () => Navigator.of(context).pop<RunningGoal>(
                  _isDistance
                      ? RunningGoal.distance(targetDistanceKm)
                      : RunningGoal.duration(targetDuration),
                ),
                child: const Text('시작'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    ),
  );
}
