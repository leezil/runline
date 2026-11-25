import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/facilities/facility.dart';
import 'package:runline/features/facilities/facility_api.dart';
import 'package:runline/features/running/running_screen.dart';
import 'package:runline/shared/widgets/runline_map_view.dart';

import 'fake_running_history.dart';
import 'fake_running_location.dart';
import 'facility_api_test.dart' show facilityJson;

void main() {
  testWidgets(
    'running screen opts into facility lookup, opens details and removes disabled markers',
    (tester) async {
      var requests = 0;
      final api = FacilityApi(
        baseUrl: 'https://example.test',
        token: 'test',
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'items': [facilityJson()],
              'truncated': false,
              'sources': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RunningScreen(
            facilityApi: api,
            history: FakeRunningHistory(),
            location: FakeRunningLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      RunlineMapView map() =>
          tester.widget<RunlineMapView>(find.byType(RunlineMapView));
      map().onBoundsChanged!(const FacilityBounds(127, 37.25, 127.02, 37.27));
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 0);
      final toggle = find.byTooltip('지도 표시');
      final toilet = find.byWidgetPredicate(
        (widget) =>
            widget is CheckboxMenuButton &&
            widget.key == const ValueKey('facility-toilet'),
      );
      expect(toilet, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toilet);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(map().facilities.single.name, '공원 화장실');
      expect(tester.widget<CheckboxMenuButton>(toilet).value, isTrue);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(toilet, findsNothing);
      map().onFacilityTap!(map().facilities.single);
      await tester.pumpAndSettle();
      expect(find.text('공원 화장실'), findsOneWidget);
      expect(find.text('상시'), findsOneWidget);
      Navigator.of(tester.element(find.text('공원 화장실'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxMenuButton>(toilet).value, isTrue);
      await tester.tap(toilet);
      await tester.pumpAndSettle();
      expect(map().facilities, isEmpty);
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
