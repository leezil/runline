import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _goalDistances = [3, 5, 10, 20];
  static const _goalTimes = [20, 30, 45, 60];

  bool _isSettingGoal = false;
  int _goalDistance = 20;
  int _goalTime = 30;

  Future<void> _openGoalPicker() async {
    final selection = await showDialog<_GoalSelection>(
      context: context,
      builder: (_) => _GoalPickerDialog(
        initialDistance: _goalDistance,
        initialTime: _goalTime,
        distances: _goalDistances,
        times: _goalTimes,
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _goalDistance = selection.distance;
        _goalTime = selection.time;
      });
    }
  }

  void _finishGoalSetting() {
    setState(() => _isSettingGoal = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_goalDistance km / $_goalTime분 목표를 설정했어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE6E9FF),
              child: Icon(Icons.person_outline, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('민지 러너', style: textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('좋은 아침이에요, 러너!', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('오늘의 목표까지 한 걸음 더 달려볼까요?', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFF7A45)),
                  const SizedBox(width: AppSpacing.xs),
                  Text('러닝 목표', style: textTheme.titleMedium),
                  const Spacer(),
                  Text('목표 20 km', style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('12.4 km', style: textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: Color(0xFFE6E9FF),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('목표의 62%를 달성했어요.', style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          onTap: () {},
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('러닝 시작하기', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text('지금 바로 새로운 러닝을 시작하세요.', style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () {},
                    icon: Icons.route_outlined,
                    label: '루트 그리기',
                    variant: AppButtonVariant.outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    onPressed: () => setState(() => _isSettingGoal = true),
                    icon: Icons.flag_outlined,
                    label: '목표 설정',
                    variant: AppButtonVariant.outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_isSettingGoal)
          Positioned.fill(
            child: _GoalSettingOverlay(
              distance: _goalDistance,
              time: _goalTime,
              onOpenGoalPicker: _openGoalPicker,
              onCancel: () => setState(() => _isSettingGoal = false),
              onStart: _finishGoalSetting,
            ),
          ),
      ],
    );
  }
}

class _GoalSettingOverlay extends StatelessWidget {
  const _GoalSettingOverlay({
    required this.distance,
    required this.time,
    required this.onOpenGoalPicker,
    required this.onCancel,
    required this.onStart,
  });

  final int distance;
  final int time;
  final VoidCallback onOpenGoalPicker;
  final VoidCallback onCancel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Container(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ),
      Center(
        child: Semantics(
          label: '목표 거리 $distance km, 목표 시간 $time분',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('목표 거리', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$distance km',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.black,
                  fontSize: 104,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '목표 시간 : $time분',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final startButtonWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 76,
                      child: AppButton(
                        label: '거리',
                        onPressed: onOpenGoalPicker,
                        variant: AppButtonVariant.outlined,
                        expand: false,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: 76,
                      child: AppButton(
                        label: '취소',
                        onPressed: onCancel,
                        variant: AppButtonVariant.text,
                        expand: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: startButtonWidth,
                  child: AppButton(
                    label: 'START',
                    onPressed: onStart,
                    size: AppButtonSize.large,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _GoalSelection {
  const _GoalSelection({required this.distance, required this.time});

  final int distance;
  final int time;
}

class _GoalPickerDialog extends StatefulWidget {
  const _GoalPickerDialog({
    required this.initialDistance,
    required this.initialTime,
    required this.distances,
    required this.times,
  });

  final int initialDistance;
  final int initialTime;
  final List<int> distances;
  final List<int> times;

  @override
  State<_GoalPickerDialog> createState() => _GoalPickerDialogState();
}

class _GoalPickerDialogState extends State<_GoalPickerDialog> {
  late int _distance;
  late int _time;

  @override
  void initState() {
    super.initState();
    _distance = widget.initialDistance;
    _time = widget.initialTime;
  }

  Future<void> _showCustomInput({required bool isDistance}) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _CustomGoalInputDialog(
        title: isDistance ? '목표 거리 직접 입력' : '목표 시간 직접 입력',
        label: isDistance ? '거리 (km)' : '시간 (분)',
        initialValue: isDistance ? _distance : _time,
      ),
    );
    if (value != null && mounted) {
      setState(() {
        if (isDistance) {
          _distance = value;
        } else {
          _time = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('목표 설정'),
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('목표 거리', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ...widget.distances.map(
                  (value) => ChoiceChip(
                    label: Text('$value km'),
                    selected: _distance == value,
                    onSelected: (_) => setState(() => _distance = value),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('직접 입력'),
                onPressed: () => _showCustomInput(isDistance: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('목표 시간', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ...widget.times.map(
                  (value) => ChoiceChip(
                    label: Text('$value분'),
                    selected: _time == value,
                    onSelected: (_) => setState(() => _time = value),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('직접 입력'),
                onPressed: () => _showCustomInput(isDistance: false),
              ),
            ],
          ),
        ],
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
    actions: [
      Row(
        children: [
          Expanded(
            child: AppButton(
              label: '취소',
              onPressed: () => Navigator.of(context).pop(),
              variant: AppButtonVariant.outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AppButton(
              label: '적용',
              onPressed: () => Navigator.of(context).pop(_GoalSelection(distance: _distance, time: _time)),
            ),
          ),
        ],
      ),
    ],
  );
}

class _CustomGoalInputDialog extends StatefulWidget {
  const _CustomGoalInputDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final int initialValue;

  @override
  State<_CustomGoalInputDialog> createState() => _CustomGoalInputDialogState();
}

class _CustomGoalInputDialogState extends State<_CustomGoalInputDialog> {
  late final TextEditingController _controller = TextEditingController(text: '${widget.initialValue}');
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _errorText = '0보다 큰 숫자를 입력하세요.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '숫자를 입력하세요',
        errorText: _errorText,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _submit(),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
    actions: [
      Row(
        children: [
          Expanded(
            child: AppButton(
              label: '취소',
              onPressed: () => Navigator.of(context).pop(),
              variant: AppButtonVariant.outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: AppButton(label: '적용', onPressed: _submit)),
        ],
      ),
    ],
  );
}
