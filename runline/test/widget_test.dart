// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/navigation/main_shell.dart';

import 'package:runline/main.dart';

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

    expect(auth.signedIn, isTrue);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(find.text('로그인이 필요합니다'), findsNothing);
  });

  testWidgets('changes activity statistics by selected period', (WidgetTester tester) async {
    await tester.pumpWidget(const RunlineApp());

    await tester.tap(find.byIcon(Icons.directions_run_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('12.4', findRichText: true), findsOneWidget);
    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();
    expect(find.textContaining('46.8', findRichText: true), findsOneWidget);
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
