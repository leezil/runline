import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:runline/features/running/route_navigation.dart';
import 'package:runline/features/running/running_location.dart';

final epoch = DateTime.utc(2026);
LatLng location(double east, [double north = 0]) =>
    LatLng(north / 111195, east / 111195);
GpsPoint fix(
  double east,
  int seconds, {
  double north = 0,
  double accuracy = 3,
}) => GpsPoint(
  north / 111195,
  east / 111195,
  accuracy,
  epoch.add(Duration(seconds: seconds)),
);
RouteNavigation straight() => RouteNavigation([location(0), location(100)]);

void main() {
  test(
    'distant rejoin requires evidence and never fills the skipped course',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2));
      nav.breakSegment();
      nav.add(fix(70, 10));
      nav.add(fix(75, 12));
      expect(nav.cursorMeters, closeTo(10, .1));
      nav.add(fix(80, 14));
      expect(nav.cursorMeters, closeTo(80, .1));
      expect(nav.passedMeters, closeTo(10, .1));
      nav.add(fix(90, 16));
      expect(nav.passedMeters, closeTo(20, .1));
      expect(nav.unpassedSegments, hasLength(2));
      expect(nav.completed, isFalse);
    },
  );
  test(
    'backtracking updates current projection without regressing route order',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2));
      nav.add(fix(20, 4));
      nav.add(fix(12, 6));
      expect(nav.cursorMeters, closeTo(20, .1));
      expect(nav.matchedMeters, closeTo(12, .1));
      expect(nav.passedMeters, closeTo(20, .1));
    },
  );
  test(
    'passage follows geometry; free distance off the route never paints it',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2));
      expect(nav.passedMeters, closeTo(10, .1));
      nav.add(fix(20, 4, north: 40));
      nav.add(fix(30, 6, north: 40));
      nav.add(fix(40, 8, north: 40));
      expect(nav.offRoute, isTrue);
      expect(nav.passedMeters, closeTo(10, .1));
      nav.add(fix(30, 10));
      nav.add(fix(40, 12));
      expect(nav.offRoute, isFalse);
      expect(nav.passedMeters, closeTo(20, .1));
      expect(nav.completedSegments, hasLength(2));
      expect(nav.completed, isFalse);
    },
  );
  test(
    'small accurate fixes accumulate passage without holes between cells',
    () {
      final nav = straight();
      for (var i = 0; i <= 100; i++) {
        nav.add(fix(i.toDouble(), i));
      }
      expect(nav.passedMeters, greaterThan(98));
      nav.add(fix(100, 101));
    },
  );
  test(
    'full traversal completes; geometry length is distinct from server target',
    () {
      final nav = straight();
      for (var i = 0; i <= 100; i += 10) {
        nav.add(fix(i.toDouble(), i ~/ 5));
      }
      expect(nav.completed, isTrue);
      expect(nav.progress, closeTo(1, .001));
      expect(nav.remainingMeters, closeTo(0, .01));
      expect(nav.directionCoordinates, isEmpty);
    },
  );
  test(
    'poor accuracy, invalid coordinates and a jump cannot complete cells',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2, accuracy: 20));
      nav.add(fix(20, 4));
      expect(nav.passedMeters, 0);
      nav.add(fix(90, 5));
      expect(nav.passedMeters, 0);
      nav.add(fix(95, 6, accuracy: double.nan));
      expect(nav.passedMeters, 0);
    },
  );
  test(
    'pause, outage and timestamp reversal do not bridge unobserved route',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2));
      nav.breakSegment();
      nav.add(fix(20, 4));
      nav.add(fix(30, 6));
      expect(nav.passedMeters, closeTo(20, .1));
      nav.add(fix(40, 40));
      expect(nav.passedMeters, closeTo(20, .1));
      nav.add(fix(50, 39));
      expect(nav.passedMeters, closeTo(20, .1));
      expect(nav.completed, isFalse);
    },
  );
  test('joining in the middle does not credit or jump to the end', () {
    final nav = straight();
    nav.add(fix(70, 0));
    nav.add(fix(80, 2));
    expect(nav.passedMeters, 0);
    expect(nav.cursorMeters, 0);
  });
  test(
    'deviation uses consecutive fixes and hysteresis, not passage tolerance',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(0, 2, north: 40));
      nav.add(fix(0, 4, north: 40));
      expect(nav.offRoute, isFalse);
      nav.add(fix(0, 6, north: 40));
      expect(nav.offRoute, isTrue);
      nav.add(fix(0, 8, north: 23));
      expect(nav.offRoute, isTrue);
      nav.add(fix(0, 10, north: 15));
      expect(nav.offRoute, isFalse);
    },
  );
  test('poor fixes do not manufacture an off-route alert', () {
    final nav = straight();
    for (var i = 0; i < 5; i++) {
      nav.add(fix(30, i, north: 90, accuracy: 70));
    }
    expect(nav.offRoute, isFalse);
    expect(nav.progress, 0);
  });
  test('crossing start/end does not jump to a later occurrence', () {
    final nav = RouteNavigation([
      location(0),
      location(60, 60),
      location(0, 60),
      location(60),
      location(0),
    ]);
    nav.add(fix(0, 0));
    nav.add(fix(10, 3, north: 10));
    expect(nav.cursorMeters, lessThan(16));
    expect(nav.progress, lessThan(.1));
    expect(nav.completed, isFalse);
  });
  test(
    'exact repeated line is traversed in order, never credited twice at once',
    () {
      final nav = RouteNavigation([
        location(0),
        location(60),
        location(0),
        location(60),
      ]);
      for (var i = 0; i <= 60; i += 10) {
        nav.add(fix(i.toDouble(), i ~/ 5));
      }
      expect(nav.cursorMeters, closeTo(60, .1));
      expect(nav.progress, closeTo(1 / 3, .01));
      for (var i = 50; i >= 0; i -= 10) {
        nav.add(fix(i.toDouble(), 12 + (60 - i) ~/ 5));
      }
      expect(nav.cursorMeters, closeTo(120, .1));
      expect(nav.progress, closeTo(2 / 3, .01));
      for (var i = 10; i <= 60; i += 10) {
        nav.add(fix(i.toDouble(), 24 + i ~/ 5));
      }
      expect(nav.completed, isTrue);
    },
  );
  test(
    'snapshot is immutable, round-trips and does not bridge restoration',
    () {
      final nav = straight();
      nav.add(fix(0, 0));
      nav.add(fix(10, 2));
      final saved = nav.snapshot;
      nav.add(fix(20, 4));
      final restored = RouteNavigation([
        location(0),
        location(100),
      ], restored: RoutePassage.fromJson(saved.toJson()));
      expect(restored.passedMeters, closeTo(10, .1));
      restored.add(fix(20, 6));
      restored.add(fix(30, 8));
      expect(restored.passedMeters, closeTo(20, .1));
      expect(saved.coveredRanges.single[1], closeTo(10, .1));
    },
  );
  test(
    'malformed and future passage extensions do not break legacy records',
    () {
      expect(RoutePassage.fromJson(null), isNull);
      expect(RoutePassage.fromJson({'version': 2}), isNull);
      expect(
        RoutePassage.fromJson({
          'version': 1,
          'cellMeters': 5,
          'totalMeters': 100,
          'cursorMeters': 20,
          'coveredCells': [],
          'coveredRanges': [
            [40, 10],
          ],
        }),
        isNull,
      );
    },
  );
}
