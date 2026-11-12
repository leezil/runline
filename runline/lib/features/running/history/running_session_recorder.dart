import 'package:flutter/foundation.dart';

import '../../route_recommendation/recommended_route.dart';
import '../running_controller.dart';
import '../running_timer.dart';
import 'running_history_repository.dart';
import 'running_record.dart';

/// Serial checkpoints every five active seconds and on each state transition.
/// Database writes use a stable ID/revision; a finished record is immutable.
class RunningSessionRecorder extends ChangeNotifier {
  RunningSessionRecorder({
    required this.run,
    required this.repository,
    this.route,
    RunningRecord? restored,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       id = restored?.id ?? RunningRecord.newId(),
       startedAt =
           restored?.startedAt ?? run.startedAt ?? (now ?? DateTime.now)(),
       _revision = restored?.revision ?? 0,
       _hasStarted = restored != null || run.hasStarted {
    run.addListener(_onChange);
    _onChange();
  }
  final RunningController run;
  final RunningHistoryRepository repository;
  final RecommendedRoute? route;
  final String id;
  final DateTime startedAt;
  final DateTime Function() _now;
  int _revision;
  RunningStatus? _lastStatus;
  Duration _lastSavedTime = const Duration(seconds: -5);
  Future<void> _pending = Future.value();
  bool _closed = false;
  bool _hasStarted;
  bool hasSaveError = false;
  RunningRecord? savedRecord;

  void _onChange() {
    if (_closed || run.timer.status == RunningStatus.ready) return;
    if (run.timer.status == RunningStatus.running ||
        run.timer.status == RunningStatus.paused) {
      _hasStarted = true;
    }
    if (!_hasStarted) return;
    if (_lastStatus != run.timer.status ||
        run.timer.elapsed - _lastSavedTime >= const Duration(seconds: 5)) {
      checkpoint();
    }
  }

  void checkpoint() {
    if (_closed || !_hasStarted || run.timer.status == RunningStatus.ready) {
      return;
    }
    _lastStatus = run.timer.status;
    _lastSavedTime = run.timer.elapsed;
    final record = RunningRecord(
      id: id,
      startedAt: startedAt,
      updatedAt: _now(),
      revision: ++_revision,
      status: run.timer.status,
      activeTime: run.timer.elapsed,
      distanceMeters: run.measurement.distanceMeters,
      points: run.measurement.points,
      segmentStarts: run.measurement.segmentStarts,
      goal: run.goal,
      route: route?.canRun == true ? route : null,
      passage: run.navigation?.snapshot,
    );
    _pending = _pending
        .then((_) => repository.save(record))
        .then(
          (_) {
            savedRecord = record;
            hasSaveError = false;
            if (!_closed) notifyListeners();
          },
          onError: (Object _, StackTrace stack) {
            hasSaveError = true;
            if (!_closed) notifyListeners();
          },
        );
  }

  Future<void> flush() => _pending;

  @override
  void dispose() {
    if (_closed) return;
    if (run.timer.status != RunningStatus.finished) run.pause();
    checkpoint();
    _closed = true;
    run.removeListener(_onChange);
    super.dispose();
  }
}
