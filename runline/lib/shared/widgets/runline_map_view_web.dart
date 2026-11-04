import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show KakaoMapOption, LatLng;
import 'package:web/web.dart' as web;

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
  });

  final LatLng initialPosition;
  final int zoomLevel;

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
        setState(() => _ready = true);
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
