import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show KakaoMapOption, LatLng;
import 'package:web/web.dart' as web;

import 'running_map_data.dart';

@JS('kakao.maps.load')
external void _loadMaps(JSFunction callback);

@JS('kakao.maps.LatLng')
extension type _Position._(JSObject _) implements JSObject {
  external factory _Position(double latitude, double longitude);
}

extension type _MapOptions._(JSObject _) implements JSObject {
  external factory _MapOptions({
    required _Position center,
    required int level,
    required bool draggable,
    required bool scrollwheel,
  });
}

@JS('kakao.maps.Map')
extension type _KakaoMap._(JSObject _) implements JSObject {
  external factory _KakaoMap(web.HTMLElement container, _MapOptions options);
  external void relayout();
  external _Position getCenter();
  external void setCenter(_Position position);
  external void setLevel(int level);
  external void setBounds(_Bounds bounds);
}

@JS('kakao.maps.LatLngBounds')
extension type _Bounds._(JSObject _) implements JSObject {
  external factory _Bounds();
  external void extend(_Position point);
}

extension type _LineOptions._(JSObject _) implements JSObject {
  external JSArray<_Position> get path;
  external factory _LineOptions({
    required JSArray<_Position> path,
    required String strokeColor,
    required int strokeWeight,
    required double strokeOpacity,
  });
}

@JS('kakao.maps.Polyline')
extension type _Polyline._(JSObject _) implements JSObject {
  external factory _Polyline(_LineOptions options);
  external void setMap(_KakaoMap? map);
  external void setPath(JSArray<_Position> path);
  external void setOptions(_LineOptions options);
}

@JS('kakao.maps.event.addListener')
external void _addMapListener(_KakaoMap map, String event, JSFunction callback);
@JS('kakao.maps.event.removeListener')
external void _removeMapListener(
  _KakaoMap map,
  String event,
  JSFunction callback,
);

@JS('kakao.maps.CustomOverlay')
extension type _LocationMarker._(JSObject _) implements JSObject {
  external factory _LocationMarker(_MarkerOptions options);
  external void setMap(_KakaoMap? map);
  external void setPosition(_Position position);
}

extension type _MarkerOptions._(JSObject _) implements JSObject {
  external factory _MarkerOptions({
    required _Position position,
    required web.HTMLElement content,
    required double xAnchor,
    required double yAnchor,
    required int zIndex,
  });
}

// Share a single SDK load between the route and running maps. Never log the
// key, script URL or native browser error (which may contain the URL).
Future<void>? _sdkReady;

Future<void> _loadSdk(String key) => _sdkReady ??= _requestSdk(key);

Future<void> _requestSdk(String key) async {
  final script = web.HTMLScriptElement()
    ..async = true
    ..src = Uri.https('dapi.kakao.com', '/v2/maps/sdk.js', {
      'appkey': key,
      'autoload': 'false',
    }).toString();
  final loaded = Completer<void>();
  final loadSubscription = script.onLoad.listen((_) {
    try {
      _loadMaps(
        () {
          if (!loaded.isCompleted) loaded.complete();
        }.toJS,
      );
    } catch (_) {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('Map SDK failed'));
      }
    }
  });
  final errorSubscription = script.onError.listen((_) {
    if (!loaded.isCompleted) loaded.completeError(StateError('Map SDK failed'));
  });
  try {
    web.document.head!.appendChild(script);
    await loaded.future.timeout(const Duration(seconds: 15));
  } catch (_) {
    script.remove();
    rethrow;
  } finally {
    await loadSubscription.cancel();
    await errorSubscription.cancel();
  }
}

class RunlineMapView extends StatefulWidget {
  const RunlineMapView({
    super.key,
    this.initialPosition = KakaoMapOption.defaultPosition,
    this.zoomLevel = KakaoMapOption.defaultZoomLevel,
    this.routeCoordinates = const [],
    this.trackSegments = const [],
    this.completedRouteSegments = const [],
    this.remainingRouteSegments,
    this.directionCoordinates = const [],
    this.currentPosition,
    this.followLocation = false,
    this.recenterToken = 0,
    this.onUserGesture,
    this.routeRun = false,
  });

  final LatLng initialPosition;
  final int zoomLevel;

  /// Immutable latitude/longitude snapshot; empty means no route overlay.
  final List<LatLng> routeCoordinates;
  final List<List<LatLng>> trackSegments, completedRouteSegments;
  final List<LatLng> directionCoordinates;
  final List<List<LatLng>>? remainingRouteSegments;
  final LatLng? currentPosition;
  final bool followLocation, routeRun;
  final int recenterToken;
  final VoidCallback? onUserGesture;

  @override
  State<RunlineMapView> createState() => _RunlineMapViewState();
}

class _RunlineMapViewState extends State<RunlineMapView> {
  static const _key = String.fromEnvironment('KAKAO_JAVASCRIPT_KEY');
  web.HTMLDivElement? _element;
  web.ResizeObserver? _resizeObserver;
  _KakaoMap? _map;
  bool _sdkLoaded = false;
  bool _failed = false;
  bool _ready = false;
  final List<_Polyline> _lines = [];
  _LocationMarker? _marker;
  JSFunction? _dragStart;
  final List<StreamSubscription<web.Event>> _interactions = [];
  bool _routeFailed = false, _fitted = false, _wasFollowing = false;
  int _lastRecenter = -1;

  @override
  void didUpdateWidget(covariant RunlineMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeCoordinates != widget.routeCoordinates) _fitted = false;
    if (oldWidget.routeCoordinates != widget.routeCoordinates ||
        oldWidget.trackSegments != widget.trackSegments ||
        oldWidget.remainingRouteSegments != widget.remainingRouteSegments ||
        oldWidget.completedRouteSegments != widget.completedRouteSegments ||
        oldWidget.directionCoordinates != widget.directionCoordinates ||
        oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.followLocation != widget.followLocation ||
        oldWidget.recenterToken != widget.recenterToken) {
      _updateRoute();
    }
  }

  void _updateRoute() {
    final map = _map;
    if (map == null) return;
    try {
      final data = runningMapLines(
        route: widget.routeCoordinates,
        remaining: widget.remainingRouteSegments,
        tracks: widget.trackSegments,
        passed: widget.completedRouteSegments,
        direction: widget.directionCoordinates,
        routeRun: widget.routeRun,
      );
      while (_lines.length > data.length) {
        _lines.removeLast().setMap(null);
      }
      for (var i = 0; i < data.length; i++) {
        final line = data[i];
        final options = _LineOptions(
          path: line.points
              .map((p) => _Position(p.latitude, p.longitude))
              .toList()
              .toJS,
          strokeColor:
              '#${line.color.toARGB32().toRadixString(16).substring(2)}',
          strokeWeight: line.width.round(),
          strokeOpacity: 1,
        );
        if (i >= _lines.length) {
          _lines.add(_Polyline(options)..setMap(map));
        } else {
          _lines[i].setOptions(options);
          _lines[i].setPath(options.path);
        }
      }
      final current = widget.currentPosition;
      if (current != null) {
        final position = _Position(current.latitude, current.longitude);
        if (_marker == null) {
          final dot = web.HTMLDivElement()
            ..setAttribute('aria-label', '현재 GPS 위치');
          dot.style.cssText = 'width:18px;height:18px;border:3px solid white;border-radius:50%;background:#00bcd4;box-shadow:0 1px 5px #555;';
          _marker = _LocationMarker(
            _MarkerOptions(
              position: position,
              content: dot,
              xAnchor: .5,
              yAnchor: .5,
              zIndex: 20000,
            ),
          )..setMap(map);
        } else {
          _marker!.setPosition(position);
        }
        if (widget.followLocation) {
          if (!_wasFollowing || _lastRecenter != widget.recenterToken) {
            map.setLevel(4);
          }
          map.setCenter(position);
        }
      } else {
        _marker?.setMap(null);
        _marker = null;
      }
      if (!_fitted && !(current != null && widget.followLocation)) {
        final points = [
          ...widget.routeCoordinates,
          ...widget.trackSegments.expand((e) => e),
        ];
        if (points.length > 1) {
          final bounds = _Bounds();
          for (final p in points) {
            bounds.extend(_Position(p.latitude, p.longitude));
          }
          map.setBounds(bounds);
        }
      }
      _fitted = true;
      _wasFollowing = current != null && widget.followLocation;
      _lastRecenter = widget.recenterToken;
      if (mounted) setState(() => _routeFailed = false);
    } catch (_) {
      if (mounted) setState(() => _routeFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_key.trim().isNotEmpty) _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadSdk(_key.trim());
      if (!mounted) return;
      _sdkLoaded = true;
      _layoutMap();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onElementCreated(Object element) {
    _element = element as web.HTMLDivElement;
    _interactions.add(
      _element!.onWheel.listen((_) => widget.onUserGesture?.call()),
    );
    _element!.style
      ..width = '100%'
      ..height = '100%';
    // Wait for DOM attachment and nonzero dimensions. Relayout when an
    // IndexedStack tab becomes visible or the browser/map area changes size.
    _resizeObserver = web.ResizeObserver(
      (JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver observer) {
        _layoutMap();
      }.toJS,
    )..observe(_element!);
  }

  void _layoutMap() {
    final element = _element;
    if (!mounted || !_sdkLoaded || _failed || element == null) return;
    if (!element.isConnected ||
        element.clientWidth == 0 ||
        element.clientHeight == 0) {
      return;
    }
    try {
      if (_map == null) {
        _map = _KakaoMap(
          element,
          _MapOptions(
            center: _Position(
              widget.initialPosition.latitude,
              widget.initialPosition.longitude,
            ),
            // Native zoom increases when zooming in; JS level decreases.
            level: (18 - widget.zoomLevel).clamp(1, 14),
            draggable: true,
            scrollwheel: true,
          ),
        );
        _dragStart = (() {
          widget.onUserGesture?.call();
        }).toJS;
        _addMapListener(_map!, 'dragstart', _dragStart!);
        setState(() => _ready = true);
        _updateRoute();
      } else {
        final center = _map!.getCenter();
        _map!.relayout();
        _map!.setCenter(center);
      }
    } catch (_) {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    try {
      if (_map != null && _dragStart != null) {
        _removeMapListener(_map!, 'dragstart', _dragStart!);
      }
      for (final line in _lines) {
        line.setMap(null);
      }
      _marker?.setMap(null);
    } catch (_) {
      /* SDK may already be gone. */
    }
    for (final subscription in _interactions) {
      subscription.cancel();
    }
    _lines.clear();
    _marker = null;
    _map = null;
    _element = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_key.trim().isEmpty) {
      return const _MapMessage(
        message: '웹 지도를 사용하려면 KAKAO_JAVASCRIPT_KEY를 설정해주세요.',
      );
    }
    if (_failed) {
      return const _MapMessage(
        message: '웹 지도를 불러오지 못했습니다. JavaScript 키, 등록 도메인 및 네트워크를 확인해주세요.',
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: _onElementCreated,
        ),
        if (_routeFailed)
          const Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Colors.white,
              child: _MapMessage(message: '경로를 지도에 표시하지 못했습니다. 다시 선택해주세요.'),
            ),
          ),
        if (!_ready)
          const IgnorePointer(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
