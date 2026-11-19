import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/stat_metric.dart';
import '../running/history/running_history_repository.dart';
import '../running/history/running_record.dart';
import '../running/history/running_record_detail_screen.dart';
import '../running/running_measurement.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityPeriod _period = _ActivityPeriod.week;
  DateTime _referenceDate = DateTime.now();

  late Future<List<RunningRecord>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    RunningHistory.completedRuns.addListener(_refreshRecords);
  }

  @override
  void dispose() {
    RunningHistory.completedRuns.removeListener(_refreshRecords);
    super.dispose();
  }

  void _loadRecords() {
    _records = RunningHistory.open().then(
      (repository) => repository.list(finished: true),
    );
  }

  void _refreshRecords() => setState(_loadRecords);

  DateTime get _periodStart => switch (_period) {
    _ActivityPeriod.week => DateTime(
      _referenceDate.year,
      _referenceDate.month,
      _referenceDate.day - _referenceDate.weekday + 1,
    ),
    _ActivityPeriod.month => DateTime(
      _referenceDate.year,
      _referenceDate.month,
    ),
    _ActivityPeriod.year => DateTime(_referenceDate.year),
  };

  DateTime get _periodEnd => switch (_period) {
    _ActivityPeriod.week => DateTime(
      _periodStart.year,
      _periodStart.month,
      _periodStart.day + 7,
    ),
    _ActivityPeriod.month => DateTime(
      _referenceDate.year,
      _referenceDate.month + 1,
    ),
    _ActivityPeriod.year => DateTime(_referenceDate.year + 1),
  };

  String get _periodRangeLabel {
    final lastDay = DateTime(
      _periodEnd.year,
      _periodEnd.month,
      _periodEnd.day - 1,
    );
    return switch (_period) {
      _ActivityPeriod.week =>
        '${_periodStart.month}월 ${_periodStart.day}일 - ${lastDay.month}월 ${lastDay.day}일',
      _ActivityPeriod.month =>
        '${_referenceDate.year}년 ${_referenceDate.month}월',
      _ActivityPeriod.year => '${_referenceDate.year}년',
    };
  }

  void _movePeriod(int direction) {
    setState(() {
      _referenceDate = switch (_period) {
        _ActivityPeriod.week => DateTime(
          _referenceDate.year,
          _referenceDate.month,
          _referenceDate.day + 7 * direction,
        ),
        _ActivityPeriod.month => DateTime(
          _referenceDate.year,
          _referenceDate.month + direction,
        ),
        _ActivityPeriod.year => DateTime(
          _referenceDate.year + direction,
          _referenceDate.month,
        ),
      };
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RunningRecord>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: _refreshRecords,
            child: const Text('기록을 불러오지 못했습니다. 다시 시도'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return _buildActivity(context, snapshot.requireData);
    },
  );

  Widget _buildActivity(BuildContext context, List<RunningRecord> records) {
    final now = DateTime.now();
    final periodRecords = records.where((record) {
      final date = record.startedAt.toLocal();
      return !date.isBefore(_periodStart) && date.isBefore(_periodEnd);
    }).toList();
    final today = _ActivityStats(
      records.where(
        (record) => DateUtils.isSameDay(record.startedAt.toLocal(), now),
      ),
    );
    final stats = _ActivityStats(periodRecords);
    final dailyMeters = <DateTime, double>{};
    for (final record in periodRecords) {
      final day = DateUtils.dateOnly(record.startedAt.toLocal());
      dailyMeters.update(
        day,
        (meters) => meters + record.distanceMeters,
        ifAbsent: () => record.distanceMeters,
      );
    }
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      key: const Key('activity-list'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('활동', style: textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('오늘의 기록과 기간별 통계를 확인하세요.', style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Text('오늘의 활동 요약', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatMetric(
                      label: '총 거리',
                      value: today.distance,
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: StatMetric(label: '시간', value: today.duration),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              const Row(
                children: [
                  Expanded(
                    child: StatMetric(label: '칼로리', value: '—', unit: 'kcal'),
                  ),
                  Expanded(
                    child: StatMetric(label: '평균 심박', value: '—', unit: 'BPM'),
                  ),
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
                  Expanded(
                    child: StatMetric(
                      label: '거리',
                      value: stats.distance,
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: StatMetric(
                      label: '러닝',
                      value: stats.runs,
                      unit: '회',
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: StatMetric(
                      label: '평균 페이스',
                      value: stats.pace,
                      unit: '/km',
                    ),
                  ),
                  Expanded(
                    child: StatMetric(label: '시간', value: stats.duration),
                  ),
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
              child: _RunningCalendar(
                period: _period,
                referenceDate: _referenceDate,
                dailyMeters: dailyMeters,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('러닝 기록', style: textTheme.titleMedium),
        if (periodRecords.isEmpty) const Text('이 기간에 완료한 러닝이 없습니다.'),
        for (final record in periodRecords)
          ListTile(
            title: Text(record.route?.name ?? '자유 러닝'),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatCompactDate(record.startedAt.toLocal())}'
              ' · ${(record.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RunningRecordDetailScreen(recordId: record.id),
              ),
            ),
          ),
      ],
    );
  }
}

enum _ActivityPeriod { week, month, year }

class _ActivityStats {
  _ActivityStats(Iterable<RunningRecord> records)
    : meters = records.fold(0.0, (sum, record) => sum + record.distanceMeters),
      elapsed = records.fold(
        Duration.zero,
        (sum, record) => sum + record.activeTime,
      ),
      runs = records.length.toString();

  final double meters;
  final Duration elapsed;
  final String runs;

  String get distance => (meters / 1000).toStringAsFixed(2);
  String get pace =>
      (RunningMeasurement()..distanceMeters = meters).pace(elapsed);
  String get duration {
    final seconds = elapsed.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _RunningCalendar extends StatelessWidget {
  const _RunningCalendar({
    required this.period,
    required this.referenceDate,
    required this.dailyMeters,
  });

  final _ActivityPeriod period;
  final DateTime referenceDate;
  final Map<DateTime, double> dailyMeters;

  @override
  Widget build(BuildContext context) {
    final calendar = switch (period) {
      _ActivityPeriod.week => _WeekCalendar(
        referenceDate: referenceDate,
        dailyMeters: dailyMeters,
      ),
      _ActivityPeriod.month => _MonthCalendar(
        year: referenceDate.year,
        month: referenceDate.month,
        dailyMeters: dailyMeters,
      ),
      _ActivityPeriod.year => _YearCalendar(
        year: referenceDate.year,
        dailyMeters: dailyMeters,
      ),
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
  const _WeekCalendar({required this.referenceDate, required this.dailyMeters});

  final DateTime referenceDate;
  final Map<DateTime, double> dailyMeters;

  @override
  Widget build(BuildContext context) {
    final firstDay = referenceDate.day - referenceDate.weekday + 1;
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: List.generate(7, (index) {
        final date = DateTime(
          referenceDate.year,
          referenceDate.month,
          firstDay + index,
        );
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                AspectRatio(
                  aspectRatio: 1,
                  child: _CalendarDay(
                    meters: dailyMeters[DateUtils.dateOnly(date)],
                    label: '${date.day}',
                  ),
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
  const _MonthCalendar({
    required this.year,
    required this.month,
    required this.dailyMeters,
  });

  final int year;
  final Map<DateTime, double> dailyMeters;
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
      _MonthGrid(year: year, month: month, dailyMeters: dailyMeters),
    ],
  );
}

class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.year, required this.dailyMeters});

  final int year;
  final Map<DateTime, double> dailyMeters;

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
        Expanded(
          child: _MonthGrid(
            year: year,
            month: index + 1,
            dailyMeters: dailyMeters,
            compact: true,
          ),
        ),
      ],
    ),
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.dailyMeters,
    this.compact = false,
  });

  final int year;
  final Map<DateTime, double> dailyMeters;
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
        return _CalendarDay(
          meters: dailyMeters[date],
          label: compact ? null : '$day',
          compact: compact,
        );
      },
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.meters,
    required this.label,
    this.compact = false,
  });

  final double? meters;
  final String? label;
  final bool compact;

  int get _stage {
    final distance = meters;
    if (distance == null) return 0;
    if (distance < 3000) return 1;
    if (distance < 7000) return 2;
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
    decoration: BoxDecoration(
      color: _color,
      borderRadius: BorderRadius.circular(compact ? 2 : 5),
    ),
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
    child: Center(
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    ),
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
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: AppSpacing.xxs),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
