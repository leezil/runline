import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/facilities/facility.dart';
import 'package:runline/features/facilities/facility_api.dart';
import 'package:runline/features/facilities/facility_controller.dart';

class FakeFacilityApi extends FacilityApi {
  final calls = <Completer<FacilityResult>>[];
  @override
  Future<FacilityResult> fetch(FacilityBounds bounds, Set<FacilityType> types) {
    final completer = Completer<FacilityResult>();
    calls.add(completer);
    return completer.future;
  }
}

void main() {
  const bounds = FacilityBounds(127, 37.25, 127.02, 37.27);
  const nearby = FacilityBounds(127.001, 37.251, 127.019, 37.269);
  const far = FacilityBounds(127.1, 37.25, 127.12, 37.27);
  const result = FacilityResult([], truncated: false);

  testWidgets('cache expiry does not poll; moving after expiry refreshes', (
    tester,
  ) async {
    final api = FakeFacilityApi();
    var now = DateTime(2026);
    final controller = FacilityController(api, now: () => now);
    addTearDown(controller.dispose);
    controller.updateBounds(bounds);
    controller.toggle(FacilityType.toilet);
    await tester.pump(const Duration(milliseconds: 600));
    api.calls.single.complete(result);
    await tester.pump();
    now = now.add(const Duration(minutes: 3));
    await tester.pump(const Duration(minutes: 3));
    expect(api.calls.length, 1);
    controller.updateBounds(nearby);
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.calls.length, 2);
    api.calls.last.complete(result);
    await tester.pump();
  });

  testWidgets('zooming into truncated results requests a smaller area', (
    tester,
  ) async {
    final api = FakeFacilityApi();
    var now = DateTime(2026);
    final controller = FacilityController(api, now: () => now);
    addTearDown(controller.dispose);
    controller.updateBounds(bounds);
    controller.toggle(FacilityType.cctv);
    await tester.pump(const Duration(milliseconds: 600));
    api.calls.single.complete(const FacilityResult([], truncated: true));
    await tester.pump();
    controller.setActive(false);
    controller.setActive(true);
    expect(controller.message, contains('일부만'));
    expect(api.calls.length, 1);
    now = now.add(const Duration(seconds: 6));
    controller.updateBounds(nearby);
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.calls.length, 2);
    api.calls.last.complete(result);
    await tester.pump();
  });

  testWidgets(
    'disabled by default; debounce, cache, throttle and background gate queries',
    (tester) async {
      final api = FakeFacilityApi();
      var now = DateTime(2026);
      final controller = FacilityController(api, now: () => now);
      addTearDown(controller.dispose);
      Future<void> advance(int milliseconds) async {
        now = now.add(Duration(milliseconds: milliseconds));
        await tester.pump(Duration(milliseconds: milliseconds));
      }

      controller.updateBounds(bounds);
      await advance(1000);
      expect(api.calls, isEmpty);
      controller.toggle(FacilityType.toilet);
      await advance(300);
      controller.updateBounds(nearby);
      await advance(300);
      expect(api.calls, isEmpty);
      await advance(300);
      expect(api.calls.length, 1);
      api.calls.last.complete(result);
      await advance(1);
      controller.updateBounds(bounds);
      await advance(600);
      expect(api.calls.length, 1);
      controller.updateBounds(far);
      await advance(600);
      expect(api.calls.length, 1);
      await advance(5000);
      expect(api.calls.length, 2);
      controller.setActive(false);
      api.calls.last.complete(result);
      await advance(1);
      controller.updateBounds(bounds);
      await advance(6000);
      expect(api.calls.length, 2);
      expect(controller.loading, false);
    },
  );

  testWidgets('one request in flight and disabling ignores late response', (
    tester,
  ) async {
    final api = FakeFacilityApi();
    var now = DateTime(2026);
    final controller = FacilityController(api, now: () => now);
    addTearDown(controller.dispose);
    controller.updateBounds(bounds);
    controller.toggle(FacilityType.cctv);
    await tester.pump(const Duration(milliseconds: 600));
    controller.updateBounds(far);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(api.calls.length, 1);
    controller.toggle(FacilityType.cctv);
    api.calls.single.complete(result);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(api.calls.length, 1);
    expect(controller.items, isEmpty);
    expect(controller.message, isNull);
  });

  testWidgets(
    'failure stops movement retries and Retry-After blocks explicit retry',
    (tester) async {
      final api = FakeFacilityApi();
      var now = DateTime(2026);
      final controller = FacilityController(api, now: () => now);
      addTearDown(controller.dispose);
      controller.updateBounds(bounds);
      controller.toggle(FacilityType.toilet);
      await tester.pump(const Duration(milliseconds: 600));
      api.calls.single.completeError(
        const FacilityApiException('wait', retryAfter: Duration(seconds: 60)),
      );
      await tester.pump();
      controller.updateBounds(far);
      await tester.pump(const Duration(seconds: 2));
      expect(api.calls.length, 1);
      controller.retry();
      await tester.pump(const Duration(milliseconds: 600));
      expect(api.calls.length, 1);
      now = now.add(const Duration(seconds: 61));
      controller.retry();
      await tester.pump(const Duration(milliseconds: 600));
      expect(api.calls.length, 2);
      api.calls.last.complete(result);
      await tester.pump();
    },
  );
}
