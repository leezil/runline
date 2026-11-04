@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/main.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('empty web key keeps both maps and running navigation usable', (
    tester,
  ) async {
    await tester.pumpWidget(const RunlineApp());
    await tester.tap(find.text('루트'));
    await tester.pumpAndSettle();
    final message = find.text('웹 지도를 사용하려면 KAKAO_JAVASCRIPT_KEY를 설정해주세요.');
    expect(message, findsOneWidget);
    expect(find.byType(RunlineMapView), findsOneWidget);
    final mapArea = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '연동 검증용 카카오맵',
    );
    expect(tester.getSize(mapArea).height, 300);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.text('러닝 진행 중'), findsOneWidget);
    expect(message, findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byType(KakaoMap, skipOffstage: false), findsNothing);
    expect(
      web.document.querySelectorAll('script[src*="dapi.kakao.com"]').length,
      0,
    );
    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    expect(find.text('오늘은 어떤 길을 달릴까요?'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
