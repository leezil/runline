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
}
