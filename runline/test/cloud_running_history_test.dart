import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:runline/features/running/history/cloud_running_history.dart';
import 'package:runline/features/running/running_timer.dart';

import 'running_history_test.dart' show historyFixture;

void main() {
  test(
    'finished run uploads once and restores GPS on another device',
    () async {
      final record = historyFixture(status: RunningStatus.finished);
      var uploads = 0;
      var detailReads = 0;
      Map<String, dynamic>? stored;
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test');
        if (request.method == 'PUT') {
          uploads++;
          stored = jsonDecode(request.body);
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/runs')) {
          final summary = Map.of(stored!)
            ..remove('points')
            ..remove('segmentStarts');
          return http.Response(
            jsonEncode({
              'records': [summary],
              'next': null,
            }),
            200,
          );
        }
        detailReads++;
        return http.Response(jsonEncode(stored), 200);
      });
      await http.runWithClient(() async {
        Future<CloudRunningHistory> device(String name) async =>
            CloudRunningHistory(
              await databaseFactoryMemory.openDatabase(name),
              'runner',
              apiOrigin: 'https://example.test',
              tokenFor: (_) async => 'test',
            );
        final first = await device('runner-one');
        final second = await device('runner-two');
        addTearDown(first.close);
        addTearDown(second.close);
        await first.save(record);
        await first.list(finished: true);
        expect(uploads, 1);
        final list = await second.list(finished: true);
        expect(list.single.points, isEmpty);
        expect(detailReads, 0);
        expect(
          (await second.read(record.id))!.points.length,
          record.points.length,
        );
        expect(
          (await second.read(record.id))!.distanceMeters,
          record.distanceMeters,
        );
        expect(detailReads, 1);
      }, () => client);
    },
  );
}
