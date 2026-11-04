// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'package:runline/app/kakao_map_bootstrap.dart';
import 'package:runline/main.dart';

void main() {
  testWidgets('shows the home tab by default', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RunlineApp());

    expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
    expect(find.text('START'), findsWidgets);
  });

  testWidgets('missing map key keeps route and home tabs usable', (
    tester,
  ) async {
    await KakaoMapBootstrap.initialize(
      nativeAppKey: '',
      abiProvider: () => 'android_arm64',
    );
    await tester.pumpWidget(const RunlineApp());

    await tester.tap(find.text('루트'));
    await tester.pumpAndSettle();
    expect(find.text('내 루트'), findsOneWidget);
    expect(find.text('지도를 사용하려면 앱 키 설정이 필요합니다.'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('x64 shows a bounded placeholder without creating KakaoMap', (
    tester,
  ) async {
    await KakaoMapBootstrap.initialize(
      nativeAppKey: 'unit-test-input',
      abiProvider: () => 'android_x64',
    );
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.text('루트'));
    await tester.pumpAndSettle();
    final message = find.text('카카오맵은 ARM64 기기에서 확인할 수 있습니다');
    expect(message, findsOneWidget);
    expect(find.byType(KakaoMap, skipOffstage: false), findsNothing);
    final mapArea = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '연동 검증용 카카오맵',
    );
    expect(tester.getSize(mapArea).height, 300);

    for (final tab in ['활동', '홈', '클럽', '피드', '루트']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
