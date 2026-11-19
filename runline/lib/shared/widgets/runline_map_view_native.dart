import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../app/kakao_map_bootstrap.dart';
import 'running_map_data.dart';

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
  final List<LatLng> routeCoordinates, directionCoordinates;
  final List<List<LatLng>> trackSegments, completedRouteSegments;
  final List<List<LatLng>>? remainingRouteSegments;
  final LatLng? currentPosition;
  final bool followLocation, routeRun;
  final int recenterToken;
  final VoidCallback? onUserGesture;
  @override
  State<RunlineMapView> createState() => _RunlineMapViewState();
}

class _RunlineMapViewState extends State<RunlineMapView> {
  bool _ready = false,
      _mapFailed = false,
      _routeFailed = false,
      _fitted = false;
  KakaoMapController? _controller;
  final List<Polyline<BasePoint>> _lines = [];
  Polygon<BasePoint>? _marker;
  Future<void> _updates = Future.value();
  int _revision = 0, _lastRecenter = -1;
  bool _wasFollowing = false;
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
      _queueUpdate();
    }
  }

  void _queueUpdate() {
    final revision = ++_revision;
    _updates = _updates.then((_) async {
      final controller = _controller;
      if (!mounted || controller == null || revision != _revision) return;
      final data = runningMapLines(
        route: widget.routeCoordinates,
        remaining: widget.remainingRouteSegments,
        tracks: widget.trackSegments,
        passed: widget.completedRouteSegments,
        direction: widget.directionCoordinates,
        routeRun: widget.routeRun,
      );
      try {
        // Reuse native shapes instead of allocating overlays on every GPS fix.
        while (_lines.length > data.length) {
          await _lines.removeLast().remove();
        }
        for (var i = 0; i < data.length; i++) {
          if (!mounted || revision != _revision) return;
          final line = data[i];
          if (i >= _lines.length) {
            _lines.add(
              await controller.shapeLayer.addPolylineShape(
                MapPoint(line.points),
                PolylineStyle(line.color, line.width),
                PolylineCap.round,
                zOrder: 10000 + i,
              ),
            );
          } else {
            await _lines[i].changePosition(MapPoint(line.points));
            if (_lines[i].style.color != line.color ||
                _lines[i].style.lineWidth != line.width) {
              await _lines[i].changeStyle(
                PolylineStyle(line.color, line.width),
                PolylineCap.round,
              );
            }
          }
        }
        final position = widget.currentPosition;
        if (position != null) {
          if (_marker == null) {
            _marker = await controller.shapeLayer.addPolygonShape(
              CirclePoint(5, position),
              PolygonStyle(
                Colors.cyan,
                strokeColor: Colors.white,
                strokeWidth: 3,
              ),
              zOrder: 20000,
            );
          } else {
            await _marker!.changePosition(CirclePoint(5, position));
          }
          if (!mounted || revision != _revision) return;
          if (widget.followLocation) {
            await controller.moveCamera(
              CameraUpdate.newCenterPosition(
                position,
                zoomLevel:
                    !_wasFollowing || _lastRecenter != widget.recenterToken
                    ? 17
                    : null,
              ),
            );
          }
        } else if (_marker != null) {
          await _marker!.remove();
          _marker = null;
        }
        if (!mounted || revision != _revision) return;
        if (!_fitted && !(position != null && widget.followLocation)) {
          final bounds = [
            ...widget.routeCoordinates,
            ...widget.trackSegments.expand((e) => e),
          ];
          if (bounds.length > 1) {
            await controller.moveCamera(
              CameraUpdate.fitMapPoints(bounds, padding: 32),
            );
          }
        }
        _fitted = true;
        _wasFollowing = position != null && widget.followLocation;
        _lastRecenter = widget.recenterToken;
        if (mounted) setState(() => _routeFailed = false);
      } catch (_) {
        if (mounted) setState(() => _routeFailed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (KakaoMapBootstrap.status) {
      KakaoMapStatus.missingKey => '지도를 사용하려면 앱 키 설정이 필요합니다.',
      KakaoMapStatus.initializationFailed => '지도 초기화에 실패했습니다.',
      KakaoMapStatus.unsupported => '현재 지도 연동은 Android에서 지원합니다.',
      KakaoMapStatus.unsupportedAbi => '카카오맵은 ARM64 기기에서 확인할 수 있습니다',
      KakaoMapStatus.initialized => null,
    };
    if (message != null) return _MapMessage(message: message);
    if (_mapFailed) return const _MapMessage(message: '지도를 불러오지 못했습니다.');
    return Stack(
      fit: StackFit.expand,
      children: [
        KakaoMap(
          option: KakaoMapOption(
            position: widget.initialPosition,
            zoomLevel: widget.zoomLevel,
          ),
          onCameraMoveStart: (gesture) {
            if (gesture != GestureType.unknown) widget.onUserGesture?.call();
          },
          onMapReady: (controller) {
            if (!mounted) return;
            _controller = controller;
            _lines.clear();
            _marker = null;
            _fitted = false;
            setState(() => _ready = true);
            _queueUpdate();
          },
          onMapError: (_) {
            if (mounted) setState(() => _mapFailed = true);
          },
        ),
        if (_routeFailed)
          const Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Colors.white,
              child: _MapMessage(message: '위치·경로를 지도에 표시하지 못했습니다.'),
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
