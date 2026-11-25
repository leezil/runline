import 'dart:math' as math;

import 'package:flutter/material.dart';

class RunningMapSheet extends StatefulWidget {
  const RunningMapSheet({
    super.key,
    required this.map,
    required this.distance,
    required this.elapsed,
    required this.pace,
    required this.details,
    required this.actions,
    this.revealDetails = false,
    this.collapsible = true,
    this.scrollableDetails = false,
  });

  final Widget map;
  final String distance, elapsed, pace;
  final Widget details;
  final Widget actions;
  final bool revealDetails;
  final bool collapsible;
  final bool scrollableDetails;

  @override
  State<RunningMapSheet> createState() => _RunningMapSheetState();
}

class _RunningMapSheetState extends State<RunningMapSheet> {
  bool _expanded = true;
  double _dragDistance = 0;

  @override
  void didUpdateWidget(covariant RunningMapSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealDetails && !oldWidget.revealDetails) _expanded = true;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final usableHeight = math.max(0.0, constraints.maxHeight - 10);
      final maxHeight = usableHeight * 0.78;
      final expanded = _expanded || !widget.collapsible;
      final label = _expanded ? '러닝 기록 접기' : '러닝 기록 펼치기';
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RunningMetrics([
              ('거리', widget.distance),
              ('시간', widget.elapsed),
              ('평균 페이스', widget.pace),
            ]),
            if (expanded) ...[
              const SizedBox(height: 8),
              const _RunningMetrics([('칼로리', '—'), ('고도', '—'), ('BPM', '—')]),
              const SizedBox(height: 12),
              widget.details,
            ],
          ],
        ),
      );
      return Column(
        children: [
          Expanded(child: widget.map),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.collapsible)
                    GestureDetector(
                      key: const Key('running-sheet-handle'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => _dragDistance = 0,
                      onVerticalDragUpdate: (details) =>
                          _dragDistance += details.delta.dy,
                      onVerticalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 200) {
                          setState(() => _expanded = velocity < 0);
                        } else if (_dragDistance.abs() > 24) {
                          setState(() => _expanded = _dragDistance < 0);
                        }
                      },
                      child: Tooltip(
                        message: label,
                        child: InkWell(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: SizedBox(
                            height: 32,
                            width: double.infinity,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!widget.collapsible) const SizedBox(height: 12),
                  Flexible(
                    child: widget.scrollableDetails && expanded
                        ? SingleChildScrollView(child: content)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: math.max(0.0, constraints.maxWidth - 24),
                              child: content,
                            ),
                          ),
                  ),
                  widget.actions,
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RunningMetrics extends StatelessWidget {
  const _RunningMetrics(this.values);

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (label, value) in values)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
    ],
  );
}
