import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/app/kakao_map_bootstrap.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/features/running/running_timer.dart';
import 'package:runline/features/running/running_goal.dart';
import 'package:runline/main.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

import 'fake_running_location.dart';

void main() {
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
    await tester.tap(find.text('종료'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.text('러닝 결과'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(RunningScreen), findsNothing);
    expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
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
