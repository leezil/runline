import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/stat_metric.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityPeriod _period = _ActivityPeriod.week;
  DateTime _referenceDate = DateTime.now();

  _ActivityStats get _stats => _ActivityStats.forPeriod(_period);

  String get _periodRangeLabel {
    switch (_period) {
      case _ActivityPeriod.week:
        final firstDay = _referenceDate.subtract(Duration(days: _referenceDate.weekday - 1));
        final lastDay = firstDay.add(const Duration(days: 6));
        return '${firstDay.month}월 ${firstDay.day}일 - ${lastDay.month}월 ${lastDay.day}일';
      case _ActivityPeriod.month:
        return '${_referenceDate.year}년 ${_referenceDate.month}월';
      case _ActivityPeriod.year:
        return '${_referenceDate.year}년';
    }
  }

  void _movePeriod(int direction) {
    setState(() {
      _referenceDate = switch (_period) {
        _ActivityPeriod.week => _referenceDate.add(Duration(days: 7 * direction)),
        _ActivityPeriod.month => DateTime(_referenceDate.year, _referenceDate.month + direction),
        _ActivityPeriod.year => DateTime(_referenceDate.year + direction, _referenceDate.month),
      };
    });
  }

  double get _calendarHeight {
    switch (_period) {
      case _ActivityPeriod.week:
        return 96;
      case _ActivityPeriod.month:
        final firstWeekday = DateTime(_referenceDate.year, _referenceDate.month, 1).weekday % 7;
        final lastDay = DateTime(_referenceDate.year, _referenceDate.month + 1, 0).day;
        final weekRows = (firstWeekday + lastDay + 6) ~/ 7;
        return weekRows == 6 ? 314 : 276;
      case _ActivityPeriod.year:
        return 464;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('활동', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('오늘의 기록과 기간별 통계를 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Text('오늘의 활동 요약', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatMetric(label: '총 거리', value: '5.2', unit: 'km')),
                  Expanded(child: StatMetric(label: '시간', value: '30:12')),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(child: StatMetric(label: '칼로리', value: '346', unit: 'kcal')),
                  Expanded(child: StatMetric(label: '평균 심박', value: '142', unit: 'BPM')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('기간별 기록', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppChip(
                label: '주',
                selected: _period == _ActivityPeriod.week,
                onTap: () => setState(() => _period = _ActivityPeriod.week),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppChip(
                label: '월',
                selected: _period == _ActivityPeriod.month,
                onTap: () => setState(() => _period = _ActivityPeriod.month),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppChip(
                label: '년',
                selected: _period == _ActivityPeriod.year,
                onTap: () => setState(() => _period = _ActivityPeriod.year),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              onPressed: () => _movePeriod(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: '이전 기간',
            ),
            Expanded(
              child: Text(
                _periodRangeLabel,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: () => _movePeriod(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: '다음 기간',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_periodRangeLabel 누적 기록', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: StatMetric(label: '거리', value: _stats.distance, unit: 'km')),
                  Expanded(child: StatMetric(label: '러닝', value: _stats.runs, unit: '회')),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(child: StatMetric(label: '평균 페이스', value: _stats.pace, unit: '/km')),
                  Expanded(child: StatMetric(label: '시간', value: _stats.duration)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('러닝 달력', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 300,
              height: _calendarHeight,
              child: _RunningCalendar(period: _period, referenceDate: _referenceDate),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ActivityPeriod { week, month, year }

class _ActivityStats {
  const _ActivityStats({
    required this.distance,
    required this.runs,
    required this.pace,
    required this.duration,
  });

  final String distance;
  final String runs;
  final String pace;
  final String duration;

  factory _ActivityStats.forPeriod(_ActivityPeriod period) => switch (period) {
    _ActivityPeriod.week => const _ActivityStats(distance: '12.4', runs: '3', pace: "6'12\"", duration: '1:17'),
    _ActivityPeriod.month => const _ActivityStats(distance: '46.8', runs: '11', pace: "6'08\"", duration: '4:47'),
    _ActivityPeriod.year => const _ActivityStats(distance: '382.6', runs: '86', pace: "6'05\"", duration: '38:46'),
  };
}

class _RunningCalendar extends StatelessWidget {
  const _RunningCalendar({required this.period, required this.referenceDate});

  final _ActivityPeriod period;
  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    final calendar = switch (period) {
      _ActivityPeriod.week => _WeekCalendar(referenceDate: referenceDate),
      _ActivityPeriod.month => _MonthCalendar(
        year: referenceDate.year,
        month: referenceDate.month,
      ),
      _ActivityPeriod.year => _YearCalendar(year: referenceDate.year),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        calendar,
        const SizedBox(height: AppSpacing.md),
        const _CalendarLegend(),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.referenceDate});

  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    final firstDay = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: List.generate(7, (index) {
        final date = firstDay.add(Duration(days: index));
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Text(labels[index], style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                AspectRatio(
                  aspectRatio: 1,
                  child: _CalendarDay(date: date, label: '${date.day}'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          _WeekdayLabel('일'),
          _WeekdayLabel('월'),
          _WeekdayLabel('화'),
          _WeekdayLabel('수'),
          _WeekdayLabel('목'),
          _WeekdayLabel('금'),
          _WeekdayLabel('토'),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      _MonthGrid(year: year, month: month),
    ],
  );
}

class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) => GridView.builder(
    itemCount: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
    ),
    itemBuilder: (context, index) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${index + 1}월', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Expanded(child: _MonthGrid(year: year, month: index + 1, compact: true)),
      ],
    ),
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.year, required this.month, this.compact = false});

  final int year;
  final int month;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final lastDay = DateTime(year, month + 1, 0).day;
    final itemCount = ((firstWeekday + lastDay + 6) ~/ 7) * 7;

    return GridView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: compact ? 1 : 3,
        mainAxisSpacing: compact ? 1 : 3,
        childAspectRatio: compact ? 1.5 : 1,
      ),
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        if (day < 1 || day > lastDay) return const SizedBox.shrink();
        final date = DateTime(year, month, day);
        return _CalendarDay(date: date, label: compact ? null : '$day', compact: compact);
      },
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.date, required this.label, this.compact = false});

  final DateTime date;
  final String? label;
  final bool compact;

  int get _stage {
    final value = (date.year * 11 + date.month * 7 + date.day * 13) % 10;
    if (value < 4) return 0;
    if (value < 6) return 1;
    if (value < 8) return 2;
    return 3;
  }

  Color get _color => switch (_stage) {
    0 => const Color(0xFFF0F2F5),
    1 => const Color(0xFFB7C5FF),
    2 => const Color(0xFF7188F7),
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(compact ? 2 : 5)),
    child: label == null
        ? null
        : Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: compact ? 0 : 10,
              color: _stage >= 2 ? Colors.white : AppColors.subText,
            ),
          ),
  );
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
  );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      _LegendItem(color: Color(0xFFF0F2F5), label: '달리지 않음'),
      _LegendItem(color: Color(0xFFB7C5FF), label: '조금 달림'),
      _LegendItem(color: Color(0xFF7188F7), label: '보통'),
      _LegendItem(color: AppColors.primary, label: '많이 달림'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: AppSpacing.xxs),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

