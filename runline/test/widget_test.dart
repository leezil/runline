// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/navigation/main_shell.dart';
import 'package:runline/features/running/history/running_history_repository.dart';
import 'package:runline/features/running/history/running_record.dart';
import 'package:runline/features/running/running_timer.dart';

import 'running_history_test.dart' show historyFixture;

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

  for (final tab in ['피드', '클럽']) {
    testWidgets('requires login before opening $tab', (tester) async {
      await tester.pumpWidget(const RunlineApp());
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();

      expect(find.text('로그인이 필요합니다'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    });
  }

  testWidgets('opens the selected tab after login succeeds', (tester) async {
    final auth = _TestAuthentication();
    await tester.pumpWidget(MaterialApp(home: MainShell(authentication: auth)));
    await tester.tap(find.text('피드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsOneWidget);
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(auth.signedIn, isTrue);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(find.text('로그인이 필요합니다'), findsNothing);
  });

  testWidgets('activity groups completed runs and opens their details', (
    tester,
  ) async {
    final repository = await RunningHistory.open();
    final record = historyFixture(status: RunningStatus.finished).toJson();
    record['startedAt'] = DateTime.now().toUtc().toIso8601String();
    await repository.save(RunningRecord.fromJson(record));

    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.byIcon(Icons.directions_run_outlined));
    await tester.pumpAndSettle();
    expect(find.text('주'), findsOneWidget);
    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('자유 러닝'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('activity-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('자유 러닝'));
    await tester.pumpAndSettle();
    expect(find.text('러닝 기록 상세'), findsOneWidget);
  });
}

class _TestAuthentication implements TabAuthentication {
  bool signedIn = false;

  @override
  Future<bool> hasSession() async => signedIn;

  @override
  Future<void> signIn() async {
    signedIn = true;
  }
}
