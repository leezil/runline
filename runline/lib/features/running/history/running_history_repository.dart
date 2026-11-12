import 'package:sembast/sembast.dart';

import 'running_record.dart';
import 'running_history_database_stub.dart'
    if (dart.library.io) 'running_history_database_io.dart'
    if (dart.library.js_interop) 'running_history_database_web.dart'
    as platform;

/// App-scoped injectable factory; tests explicitly substitute a memory DB.
class RunningHistory {
  static Future<RunningHistoryRepository> Function() open = _openLocal;
  static Future<RunningHistoryRepository>? _local;
  static Future<RunningHistoryRepository> _openLocal() => _local ??= platform
      .openDatabase()
      .then(RunningHistoryRepository.new)
      .onError((error, stack) {
        _local = null;
        Error.throwWithStackTrace(error!, stack);
      });
}

/// Activity can query this layer without depending on the running screen.
abstract interface class RunningHistoryRepository {
  factory RunningHistoryRepository(Database database) =
      SembastRunningHistoryRepository;
  Future<void> save(RunningRecord record);
  Future<RunningRecord?> read(String id);
  Future<List<RunningRecord>> list({required bool finished});
  Future<void> close();
}

class SembastRunningHistoryRepository implements RunningHistoryRepository {
  SembastRunningHistoryRepository(this.database);
  final Database database;
  final _records = stringMapStoreFactory.store('running_sessions_v1');

  @override
  Future<void> save(RunningRecord record) => database.transaction((txn) async {
    final ref = _records.record(record.id);
    final old = await ref.get(txn);
    if (old != null &&
        ((old['revision'] as int) >= record.revision ||
            old['status'] == 'finished')) {
      return;
    }
    await ref.put(txn, record.toJson());
  });

  @override
  Future<RunningRecord?> read(String id) async {
    final json = await _records.record(id).get(database);
    return json == null ? null : RunningRecord.fromJson(json);
  }

  @override
  Future<List<RunningRecord>> list({required bool finished}) async {
    final snapshots = await _records.find(
      database,
      finder: Finder(
        filter: finished
            ? Filter.equals('status', 'finished')
            : Filter.notEquals('status', 'finished'),
        sortOrders: [SortOrder('updatedAt', false)],
      ),
    );
    return List.unmodifiable(
      snapshots.map((s) => RunningRecord.fromJson(s.value)),
    );
  }

  @override
  Future<void> close() => database.close();
}
