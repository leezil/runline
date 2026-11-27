import 'route_place_search_stub.dart'
    if (dart.library.js_interop) 'route_place_search_web.dart'
    as platform;

typedef RoutePlace = ({
  String name,
  String address,
  double longitude,
  double latitude,
});
typedef RoutePlaceSearch = Future<List<RoutePlace>> Function(String query);

const canSearchRoutePlaces = platform.canSearchRoutePlaces;

Future<List<RoutePlace>> searchRoutePlaces(String query) =>
    platform.searchRoutePlaces(query);
