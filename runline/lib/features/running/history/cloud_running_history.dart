import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';

import '../../auth/runline_auth.dart';
import 'running_history_repository.dart';
import 'running_record.dart';

class CloudRunningHistory extends SembastRunningHistoryRepository {
  CloudRunningHistory(
    Database db,
    this.owner, {
    this.apiOrigin = const String.fromEnvironment('RUNLINE_API_ORIGIN'),
    Future<String> Function(String)? tokenFor,
  }) : _tokenFor = tokenFor ?? RunlineAuth.shared.tokenFor,
       _uploaded = StoreRef<String, bool>('uploaded_$owner'),
       _summaries = stringMapStoreFactory.store('summaries_$owner'),
       super(db, 'runs_$owner');
  final String owner;
  final String apiOrigin;
  final Future<String> Function(String) _tokenFor;
  final StoreRef<String, bool> _uploaded;
  final StoreRef<String, Map<String, Object?>> _summaries;
  final _uploads = <String, Future<void>>{};

  Future<http.Response> _request(String path, {RunningRecord? record}) async {
    final base = Uri.parse(apiOrigin);
    if (base.scheme != 'https' || base.host.isEmpty) {
      throw StateError('Invalid API origin');
    }
    final uri = base.resolve('/api/v1/me/runs$path');
    final headers = {'Authorization': 'Bearer ${await _tokenFor(owner)}'};
    final response =
        await (record == null
                ? http.get(uri, headers: headers)
                : http.put(
                    uri,
                    headers: {...headers, 'Content-Type': 'application/json'},
                    body: jsonEncode(record.toJson()),
                  ))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('History API ${response.statusCode}');
    }
    return response;
  }

  Future<void> _upload(RunningRecord r) => _uploads
      .putIfAbsent(r.id, () async {
        if (await _uploaded.record(r.id).get(database) == true) return;
        await _request('/${r.id}', record: r);
        await _uploaded.record(r.id).put(database, true);
      })
      .whenComplete(() {
        _uploads.remove(r.id);
      });

  @override
  Future<void> save(RunningRecord record) async {
    await super.save(record);
    if (record.isFinished) unawaited(_upload(record).catchError((Object _) {}));
  }

  Future<List<RunningRecord>>? _listing;

  @override
  Future<List<RunningRecord>> list({required bool finished}) {
    if (!finished) return super.list(finished: false);
    return _listing ??= _loadFinished().whenComplete(() {
      _listing = null;
    });
  }

  Future<List<RunningRecord>> _loadFinished() async {
    final local = await super.list(finished: true);
    try {
      for (final r in local) {
        await _upload(r);
      }
      String? after;
      do {
        final response = await _request(after == null ? '' : '?after=$after');
        final page = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        await database.transaction((txn) async {
          for (final row in page['records'] as List) {
            await _summaries.record(row['id'] as String).put(txn, {
              ...Map<String, Object?>.from(row as Map),
              'points': [],
              'segmentStarts': [],
            });
          }
        });
        after = page['next'] as String?;
      } while (after != null);
    } catch (_) {
      if (local.isEmpty && await _summaries.count(database) == 0) rethrow;
    }
    final rows = {
      for (final s in await _summaries.find(database))
        s.key: RunningRecord.fromJson(s.value),
      for (final r in local) r.id: r,
    };
    return rows.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<RunningRecord?> read(String id) async {
    final local = await super.read(id);
    if (local != null) return local;
    final response = await _request('/$id');
    final record = RunningRecord.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
    await _uploaded.record(id).put(database, true);
    await super.save(record);
    return record;
  }
}
