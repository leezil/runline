import 'dart:async';
import 'dart:js_interop';

import '../../shared/widgets/runline_map_view_web.dart';
import 'route_place_search.dart';

const _key = String.fromEnvironment('KAKAO_JAVASCRIPT_KEY');
const canSearchRoutePlaces = _key != '';

@JS('kakao.maps.services.Places')
extension type _Places._(JSObject _) implements JSObject {
  external factory _Places();
  external void keywordSearch(String query, JSFunction callback);
}

@JS('kakao.maps.services.Geocoder')
extension type _Geocoder._(JSObject _) implements JSObject {
  external factory _Geocoder();
  external void addressSearch(String query, JSFunction callback);
}

extension type _Result._(JSObject _) implements JSObject {
  @JS('place_name')
  external String? get placeName;
  @JS('road_address_name')
  external String? get roadAddressName;
  @JS('address_name')
  external String get addressName;
  external String get x;
  external String get y;
}

Future<List<RoutePlace>> searchRoutePlaces(String query) async {
  await loadRunlineKakaoMaps(_key.trim());
  Future<List<RoutePlace>> request(void Function(String, JSFunction) lookup) {
    final result = Completer<List<RoutePlace>>();
    lookup(
      query,
      (JSArray<_Result> rows, String status) {
        if (result.isCompleted) return;
        if (status == 'ZERO_RESULT') {
          result.complete([]);
        } else if (status == 'OK') {
          final matches = <RoutePlace>[];
          for (final row in rows.toDart) {
            final longitude = double.tryParse(row.x);
            final latitude = double.tryParse(row.y);
            if (longitude == null || latitude == null) continue;
            final roadAddress = row.roadAddressName;
            matches.add((
              name: row.placeName ?? row.addressName,
              address: roadAddress == null || roadAddress.isEmpty
                  ? row.addressName
                  : roadAddress,
              longitude: longitude,
              latitude: latitude,
            ));
            if (matches.length == 5) break;
          }
          result.complete(matches);
        } else {
          result.completeError(StateError('Place search failed'));
        }
      }.toJS,
    );
    return result.future.timeout(const Duration(seconds: 10));
  }

  final matches = await request(
    (query, callback) => _Places().keywordSearch(query, callback),
  );
  return matches.isNotEmpty
      ? matches
      : request((query, callback) => _Geocoder().addressSearch(query, callback));
}
