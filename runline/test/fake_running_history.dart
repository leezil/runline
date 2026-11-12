import 'package:runline/features/running/history/running_history_repository.dart';
import 'package:runline/features/running/history/running_record.dart';

/// Widget dependency only. Repository persistence tests use real Sembast.
class FakeRunningHistory implements RunningHistoryRepository {
  final records = <String, RunningRecord>{};
  bool failWrites = false;
  @override
  Future<void> save(RunningRecord record) async {
    if (failWrites) throw StateError('Storage unavailable');
    final old = records[record.id];
    if (old == null || (!old.isFinished && old.revision < record.revision)) {
      records[record.id] = RunningRecord.fromJson(record.toJson());
    }
  }

  @override
  Future<RunningRecord?> read(String id) async => records[id];
  @override
  Future<List<RunningRecord>> list({required bool finished}) async =>
      records.values.where((r) => r.isFinished == finished).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  @override
  Future<void> close() async {}
}
