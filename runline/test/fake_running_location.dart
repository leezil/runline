import 'dart:async';

import 'package:runline/features/running/running_location.dart';

class FakeRunningLocation implements RunningLocation {
  GpsStatus? failure;
  int subscriptions = 0;
  int cancellations = 0;
  late final controller = StreamController<GpsPoint>.broadcast(
    sync: true,
    onListen: () => subscriptions++,
    onCancel: () => cancellations++,
  );
  @override
  Future<GpsStatus?> prepare() async => failure;
  @override
  Stream<GpsPoint> positions() => controller.stream;
}
