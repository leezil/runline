// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runline/main.dart';
import 'package:runline/shared/widgets/app_button.dart';
import 'package:runline/shared/widgets/app_chip.dart';

void main() {
  testWidgets('shows the home tab by default', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RunlineApp());

    expect(find.text('좋은 아침이에요, 러너!'), findsOneWidget);
    expect(find.text('러닝 목표'), findsOneWidget);
  });

  testWidgets('changes activity statistics by selected period', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    await tester.tap(find.byIcon(Icons.directions_run_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('12.4', findRichText: true), findsOneWidget);
    final monthChip = find.ancestor(
      of: find.text('월'),
      matching: find.byType(AppChip),
    );
    await tester.ensureVisible(monthChip);
    await tester.tap(monthChip);
    await tester.pumpAndSettle();
    expect(find.textContaining('46.8', findRichText: true), findsOneWidget);
  });

  testWidgets('supports shared button variants and loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppButton(label: '저장', onPressed: () {}),
              AppButton(
                label: '취소',
                onPressed: () {},
                variant: AppButtonVariant.outlined,
              ),
              AppButton(
                label: '처리 중',
                onPressed: () {},
                isLoading: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('저장'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('opens and closes the settings screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 편집'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('러닝 목표'), findsOneWidget);
  });

  testWidgets('opens the goal-setting overlay from home', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    final homeScrollView = find.ancestor(
      of: find.text('러닝 시작하기'),
      matching: find.byType(Scrollable),
    );
    await tester.drag(homeScrollView, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목표 설정'));
    await tester.pumpAndSettle();

    expect(find.text('20 km'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('거리'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
  });

  testWidgets('opens the distance and time goal picker', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    final homeScrollView = find.ancestor(
      of: find.text('러닝 시작하기'),
      matching: find.byType(Scrollable),
    );
    await tester.drag(homeScrollView, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목표 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('거리'));
    await tester.pumpAndSettle();

    expect(find.text('목표 거리'), findsWidgets);
    expect(find.text('목표 시간'), findsWidgets);
    expect(find.text('20 km'), findsWidgets);
    expect(find.text('30분'), findsOneWidget);
  });

  testWidgets('opens a text field for a custom goal value', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    final homeScrollView = find.ancestor(
      of: find.text('러닝 시작하기'),
      matching: find.byType(Scrollable),
    );
    await tester.drag(homeScrollView, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목표 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('거리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('직접 입력').first);
    await tester.pumpAndSettle();

    expect(find.text('목표 거리 직접 입력'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('opens the route drawing flow from home', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    final homeScrollView = find.ancestor(
      of: find.text('러닝 시작하기'),
      matching: find.byType(Scrollable),
    );
    await tester.drag(homeScrollView, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('루트 그리기'));
    await tester.pumpAndSettle();

    expect(find.text('달리고 싶은 그림을 그려보세요!'), findsOneWidget);
  });

  testWidgets('opens a saved route detail from the route tab', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.byIcon(Icons.alt_route_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('한강 여의도 순환 코스'), 200);
    await tester.tap(find.text('한강 여의도 순환 코스'));
    await tester.pumpAndSettle();

    expect(find.text('피드에 공유하기'), findsOneWidget);
    expect(find.text('5.1km'), findsWidgets);
  });

  testWidgets('opens feed post detail and author profile', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('오늘은 별 하나를 달렸어요 ⭐'));
    await tester.pumpAndSettle();
    expect(find.text('굿ㅈㄷ'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('민'),
        matching: find.byType(CircleAvatar),
      ).first,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
  });

  testWidgets('shows the photo preview in a photo feed detail', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('가을 한강은 언제나 좋아요 🍂'), 200);
    await tester.tap(find.text('가을 한강은 언제나 좋아요 🍂'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

}
