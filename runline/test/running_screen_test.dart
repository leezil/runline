import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/app/kakao_map_bootstrap.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/features/running/running_map_sheet.dart';
import 'package:runline/features/running/running_timer.dart';
import 'package:runline/features/running/running_goal.dart';
import 'package:runline/main.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

import 'fake_running_location.dart';
import 'fake_running_history.dart';

import 'package:runline/features/running/running_location.dart';

void main() {
  testWidgets(
    'Android keeps one GPS stream across screen lock and saves background points',
    (tester) async {
      final history = FakeRunningHistory();
      final gps = FakeRunningLocation();
      var elapsed = Duration.zero;
      late RunningTimer timer;
      await tester.pumpWidget(
        MaterialApp(
          home: RunningScreen(
            location: gps,
            history: history,
            createTimer: () => timer = RunningTimer(now: () => elapsed),
          ),
        ),
      );
      await tester.pump();
      expect(gps.subscriptions, 1);
      final now = DateTime.now();
      gps.controller.add(
        GpsPoint(37.28, 127.01, 3, now.subtract(const Duration(seconds: 5))),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      elapsed = const Duration(seconds: 5);
      gps.controller.add(GpsPoint(37.2801, 127.01, 3, now));
      await tester.pump(const Duration(seconds: 5));
      expect(timer.status, RunningStatus.running);
      expect(history.records.values.single.points.length, 2);
      expect(history.records.values.single.activeTime, elapsed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gps.subscriptions, 1);
      expect(gps.cancellations, 0);
      await tester.tap(find.text('종료'));
      await tester.pumpAndSettle();
      expect(gps.cancellations, 1);
      expect(history.records.values.single.isFinished, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final goal in [
    const RunningGoal.distance(7),
    const RunningGoal.duration(Duration(minutes: 5)),
  ]) {
    testWidgets('$goal displays on 320px and never auto-finishes the timer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = Duration.zero;
      late RunningTimer timer;
      await tester.pumpWidget(
        MaterialApp(
          home: RunningScreen(
            location: FakeRunningLocation(),
            goal: goal,
            createTimer: () => timer = RunningTimer(now: () => now),
          ),
        ),
      );
      expect(
        find.text(goal is DistanceGoal ? '목표 7.00 km' : '목표 05:00'),
        findsOneWidget,
      );
      now = const Duration(minutes: 6);
      await tester.pump(const Duration(minutes: 6));
      expect(
        timer.status,
        RunningStatus.running,
        reason: tester.widget<Text>(find.byKey(const Key('gps-status'))).data,
      );
      final map = find.byType(RunlineMapView);
      final handle = find.byKey(const Key('running-sheet-handle'));
      final expandedMapHeight = tester.getSize(map).height;
      expect(find.text('BPM').hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RunningMapSheet),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      await tester.drag(handle, const Offset(0, 250));
      await tester.pumpAndSettle();
      final compactMapHeight = tester.getSize(map).height;
      expect(compactMapHeight, greaterThan(520));
      expect(compactMapHeight, greaterThan(expandedMapHeight));
      expect(tester.getSize(map).width, 320);
      for (final label in ['거리', '시간', '평균 페이스']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(find.text('BPM').hitTestable(), findsNothing);
      await tester.drag(handle, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getSize(map).height, lessThan(compactMapHeight));
      expect(find.text('BPM').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('구간 페이스'), findsOneWidget);
      expect(find.text('1km를 완료하면 구간 페이스가 표시됩니다.'), findsOneWidget);
      await tester.tap(find.text('06:00'));
      await tester.pumpAndSettle();
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      expect(find.text("--'--\""), findsOneWidget);
      await tester.tap(find.text('일시정지'));
      await tester.pump();
      expect(timer.status, RunningStatus.paused);
      await tester.tap(find.text('재개'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(
        timer.status,
        RunningStatus.running,
        reason: tester.widget<Text>(find.byKey(const Key('gps-status'))).data,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('START pushes running UI and finish returns to the home tab', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await KakaoMapBootstrap.initialize(
      nativeAppKey: 'unit-test-input',
      abiProvider: () => 'android_x64',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();

    expect(find.byType(RunningScreen), findsOneWidget);
    expect(find.text('러닝 시작 준비'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(RunlineMapView), findsOneWidget);
    expect(find.text('카카오맵은 ARM64 기기에서 확인할 수 있습니다'), findsOneWidget);
    expect(find.byType(KakaoMap, skipOffstage: false), findsNothing);
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text("--'--\""), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );

    expect(tester.takeException(), isNull);
    final map = find.byType(RunlineMapView);
    final handle = find.byKey(const Key('running-sheet-handle'));
    final expandedMapHeight = tester.getSize(map).height;
    for (final label in ['거리', '시간', '평균 페이스', '칼로리', '고도', 'BPM']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(find.byKey(const Key('running-goal-label')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RunningMapSheet),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    await tester.tap(find.text('구간'));
    await tester.pumpAndSettle();
    expect(find.text('구간 페이스').hitTestable(), findsOneWidget);
    await tester.tap(find.text('러닝'));
    await tester.pumpAndSettle();
    expect(map.hitTestable(), findsOneWidget);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    final compactMapHeight = tester.getSize(map).height;
    expect(compactMapHeight, greaterThan(expandedMapHeight));
    expect(find.text('BPM'), findsNothing);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gps-status')).hitTestable(), findsOneWidget);
    expect(tester.getSize(map).height, expandedMapHeight);

    await tester.tap(find.text('종료'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('러닝 결과'), findsOneWidget);
    expect(tester.getSize(map).height, greaterThan(expandedMapHeight));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(RunningScreen), findsNothing);
    expect(find.text('좋은 아침이에요, 러너!'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('좋은 아침이에요, 러너!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('active time advances, excludes pauses, and restarts fresh', (
    tester,
  ) async {
    var now = Duration.zero;
    late RunningTimer timer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => RunningScreen(
                    location: FakeRunningLocation(),
                    createTimer: () {
                      timer = RunningTimer(now: () => now);
                      return timer;
                    },
                  ),
                ),
              ),
              child: const Text('START'),
            ),
          ),
        ),
      ),
    );

    Future<void> advance(Duration duration) async {
      now += duration;
      await tester.pump(duration);
    }

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(
      timer.status,
      RunningStatus.running,
      reason: tester.widget<Text>(find.byKey(const Key('gps-status'))).data,
    );
    expect(find.text('00:00'), findsOneWidget);
    await advance(const Duration(milliseconds: 2500));
    expect(find.text('00:02'), findsOneWidget);

    await tester.tap(find.text('일시정지'));
    await tester.pump();
    expect(timer.status, RunningStatus.paused);
    expect(find.text('러닝 일시정지'), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);
    await advance(const Duration(minutes: 3));
    expect(find.text('00:02'), findsOneWidget);
    expect(timer.elapsed, const Duration(milliseconds: 2500));

    await tester.tap(find.text('재개'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('일시정지'), findsOneWidget);
    expect(find.text('러닝 진행 중'), findsOneWidget);
    await advance(const Duration(milliseconds: 500));
    expect(find.text('00:03'), findsOneWidget);
    await advance(const Duration(seconds: 58));
    expect(find.text('01:01'), findsOneWidget);
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text("--'--\""), findsOneWidget);

    await tester.tap(find.text('종료'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('러닝 결과'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(timer.status, RunningStatus.finished);
    expect(find.byType(RunningScreen), findsNothing);
    await advance(const Duration(seconds: 5));
    expect(timer.elapsed, const Duration(seconds: 61));

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.text('00:00'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await advance(const Duration(seconds: 2));
    expect(timer.status, RunningStatus.finished);
    expect(timer.elapsed, Duration.zero);
    expect(find.byType(RunningScreen), findsNothing);
    expect(tester.takeException(), isNull);
    // flutter_test also fails this test if dispose leaves a periodic timer.
  });
}
