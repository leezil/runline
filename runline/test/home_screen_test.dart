import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/home/running_goal_dialog.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/features/running/running_goal.dart';
import 'package:runline/main.dart';

void main() {
  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1920, 1080),
  ]) {
    testWidgets('home actions fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const RunlineApp());

      expect(find.text('좋은 아침이에요, 러너!'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('러닝 목표'), findsOneWidget);
      expect(tester.getSize(find.byType(NavigationBar)).width, size.width);
      final start = find.byKey(const Key('home-start-button'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      final startButton = tester.widget<ElevatedButton>(start);
      expect(startButton.onPressed, isNotNull);
      expect(startButton.style?.shape?.resolve({}), isA<CircleBorder>());
      expect(tester.getSize(start), const Size.square(220));
      expect(tester.getCenter(start).dx, closeTo(size.width / 2, 0.1));

      await tester.ensureVisible(find.text('목표 설정'));
      await tester.pumpAndSettle();
      expect(find.text('루트 그리기'), findsOneWidget);
      expect(find.text('목표 설정'), findsOneWidget);
      final routeRect = tester.getRect(find.text('루트 그리기'));
      final goalRect = tester.getRect(find.text('목표 설정'));
      expect(routeRect.center.dx, lessThan(goalRect.center.dx));
      expect(routeRect.center.dy, closeTo(goalRect.center.dy, 0.1));
      expect(tester.getRect(start).bottom, lessThan(routeRect.top));
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsOneWidget);
      expect(find.text('7.00'), findsOneWidget);
      expect(find.text('거리'), findsOneWidget);
      expect(find.text('오늘의 목표'), findsOneWidget);
      await selectType(tester, '시간');
      expect(find.text('00:30'), findsOneWidget);
      final rect = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(rect.right - 24, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsNothing);
      expect(find.text('좋은 아침이에요, 러너!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'cancel discards distance edits and reopens with the default goal',
    (tester) async {
      await tester.pumpWidget(const RunlineApp());
      await tester.ensureVisible(find.text('목표 설정'));
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      expect(find.text('7.00'), findsOneWidget);
      await tester.tap(find.byTooltip('목표 거리 늘리기'));
      await tester.pump();
      expect(find.text('7.50'), findsOneWidget);
      await tester.tap(find.byTooltip('목표 거리 줄이기'));
      await tester.pump();
      expect(find.text('7.00'), findsOneWidget);

      final sliderFinder = find.byType(Slider);
      final sliderRect = tester.getRect(sliderFinder);
      await tester.tapAt(Offset(sliderRect.right - 24, sliderRect.center.dy));
      await tester.pumpAndSettle();
      final edited = tester.widget<Slider>(sliderFinder).value;
      expect(edited, greaterThan(7));
      expect(edited * 2, (edited * 2).roundToDouble());
      expect(find.text('${edited.toStringAsFixed(2)}'), findsOneWidget);
      await selectType(tester, '시간');
      await tester.tap(find.byTooltip('목표 시간 늘리기'));
      await tester.pump();
      expect(find.text('00:35'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsNothing);
      expect(find.byType(RunningScreen), findsNothing);
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      expect(find.text('7.00'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goal START passes selected distance and direct START stays usable',
    (tester) async {
      await tester.pumpWidget(const RunlineApp());
      await tester.ensureVisible(find.text('목표 설정'));
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('목표 거리 늘리기'));
      await tester.pump();
      expect(find.text('7.50'), findsOneWidget);
      await tester.tap(find.byKey(const Key('target-start-button')));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsNothing);
      expect(find.byType(RunningScreen), findsOneWidget);
      expect(
        tester.widget<RunningScreen>(find.byType(RunningScreen)).goal,
        isA<DistanceGoal>().having(
          (goal) => goal.distanceKm,
          'distanceKm',
          7.5,
        ),
      );
      expect(find.text('목표 7.50 km'), findsOneWidget);
      expect(find.text('러닝 시작 준비'), findsOneWidget);
      await tester.longPress(find.text('종료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsNothing);
      final homeStart = find.byKey(const Key('home-start-button'));
      await tester.ensureVisible(homeStart);
      await tester.tap(homeStart);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RunningScreen>(find.byType(RunningScreen)).goal,
        isNull,
      );
      expect(find.byKey(const Key('running-goal-label')), findsNothing);
      await tester.tap(find.text('종료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'goal types keep drafts and duration controls use five-minute steps',
    (tester) async {
      await tester.pumpWidget(const RunlineApp());
      await tester.ensureVisible(find.text('목표 설정'));
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('목표 거리 늘리기'));
      await tester.pump();
      expect(find.text('7.50'), findsOneWidget);
      await selectType(tester, '시간');
      expect(find.text('00:30'), findsOneWidget);
      final sliderFinder = find.byType(Slider);
      var slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, 5);
      expect(slider.max, 300);
      expect(slider.divisions, 59);
      await tester.tap(find.byTooltip('목표 시간 늘리기'));
      await tester.pump();
      expect(find.text('00:35'), findsOneWidget);
      await tester.tap(find.byTooltip('목표 시간 줄이기'));
      await tester.pump();
      expect(find.text('00:30'), findsOneWidget);
      final rect = tester.getRect(sliderFinder);
      await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('00:05'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == '목표 시간 줄이기',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tapAt(Offset(rect.right - 24, rect.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == '목표 시간 늘리기',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.dragFrom(rect.center, const Offset(10, 0));
      await tester.pumpAndSettle();
      slider = tester.widget<Slider>(sliderFinder);
      final minutes = slider.value.toInt();
      expect(minutes, inInclusiveRange(5, 300));
      expect(minutes % 5, 0);
      await selectType(tester, '거리');
      expect(find.text('7.50'), findsOneWidget);
      await selectType(tester, '시간');
      final hoursText = (minutes ~/ 60).toString().padLeft(2, '0');
      final minutesText = (minutes % 60).toString().padLeft(2, '0');
      expect(find.text('$hoursText:$minutesText'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duration START passes a Duration goal and displays it in running',
    (tester) async {
      await tester.pumpWidget(const RunlineApp());
      await tester.ensureVisible(find.text('목표 설정'));
      await tester.tap(find.text('목표 설정'));
      await tester.pumpAndSettle();
      await selectType(tester, '시간');
      await tester.tap(find.byTooltip('목표 시간 늘리기'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('target-start-button')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RunningScreen>(find.byType(RunningScreen)).goal,
        isA<DurationGoal>().having(
          (goal) => goal.duration,
          'duration',
          const Duration(minutes: 35),
        ),
      );
      expect(find.text('목표 35:00'), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text("--'--\""), findsOneWidget);
      await tester.longPress(find.text('종료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byType(RunningGoalDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
