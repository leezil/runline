import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/test_map_placeholder.dart';

class RunningProgressScreen extends StatefulWidget {
  const RunningProgressScreen({super.key, this.goalDistance, this.goalTime});

  final int? goalDistance;
  final int? goalTime;

  @override
  State<RunningProgressScreen> createState() => _RunningProgressScreenState();
}

class _RunningProgressScreenState extends State<RunningProgressScreen> {
  Timer? _timer;
  var _elapsedSeconds = 67;
  var _isPaused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: 350,
            height: 250,
            child: TestMapPlaceholder(height: 250, borderRadius: 18),
          ),
          Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Metric(label: '페이스', icon: Icons.show_chart, value: "5'43\""),
                    _Metric(label: '심박수', icon: Icons.favorite, value: '145'),
                    _Metric(label: '시간', icon: Icons.timer_outlined, value: _elapsed),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Icon(Icons.flag, size: 18, color: AppColors.primary),
              const SizedBox(height: AppSpacing.xxs),
              const Text('러닝거리', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                '5.78Km',
                style: TextStyle(color: AppColors.primary, fontSize: 74, fontWeight: FontWeight.w900, letterSpacing: -4),
              ),
              if (widget.goalDistance != null || widget.goalTime != null)
                Text(
                  '목표 ${widget.goalDistance ?? '-'} km · ${widget.goalTime ?? '-'}분',
                  style: const TextStyle(color: AppColors.subText),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xxl,
            child: Center(
              child: _RunningControlButton(
                label: _isPaused ? '러닝 재개' : '러닝 일시정지',
                color: AppColors.primary,
                icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: () => setState(() => _isPaused = !_isPaused),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.xl,
            bottom: 64,
            child: IconButton(
              onPressed: () {
                _timer?.cancel();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop_rounded),
              iconSize: 38,
              color: const Color(0xFFD92D20),
              tooltip: '러닝 중지',
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.icon, required this.value});
  final String label, value; final IconData icon;
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: AppColors.primary), const SizedBox(width: 4), Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))]),
    const SizedBox(height: AppSpacing.xs),
    Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -2)),
  ]);
}

class _RunningControlButton extends StatelessWidget {
  const _RunningControlButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: .28), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, color: Colors.white, size: 48),
      ),
    ),
  );
}

