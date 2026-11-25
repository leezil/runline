import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import 'running_record.dart';
import '../../auth/runline_auth.dart';
import 'cloud_running_history.dart';
import 'running_history_database_stub.dart'
    if (dart.library.io) 'running_history_database_io.dart'
    if (dart.library.js_interop) 'running_history_database_web.dart'
    as platform;

/// App-scoped injectable factory; tests explicitly substitute a memory DB.
class RunningHistory {
  static Future<RunningHistoryRepository> Function() open = _openLocal;
  static final _completedRuns = ValueNotifier<int>(0);
  static ValueListenable<int> get completedRuns => _completedRuns;
  static void notifyRunCompleted() => _completedRuns.value++;

  static Future<Database>? _database;
  static final _accounts = <String, CloudRunningHistory>{};
  static Future<RunningHistoryRepository> _openLocal() async {
    final owner = RunlineAuth.instance.userId;
    final db = await (_database ??= platform.openDatabase().onError((
      error,
      stack,
    ) {
      _database = null;
      Error.throwWithStackTrace(error!, stack);
    }));
    if (owner == null) return RunningHistoryRepository(db);
    return _accounts.putIfAbsent(owner, () => CloudRunningHistory(db, owner));
  }
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
  SembastRunningHistoryRepository(
    this.database, [
    String store = 'running_sessions_v1',
  ]) : _records = stringMapStoreFactory.store(store);
  final Database database;
  final StoreRef<String, Map<String, Object?>> _records;

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
