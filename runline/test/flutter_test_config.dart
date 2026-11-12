import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/running/history/running_history_repository.dart';

import 'fake_running_history.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    // Explicit test dependency: no device storage or generated GPS positions.
    final repository = FakeRunningHistory();
    RunningHistory.open = () async => repository;
  });
  await testMain();
}
