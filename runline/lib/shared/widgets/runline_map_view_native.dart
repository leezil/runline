import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import '../../app/kakao_map_bootstrap.dart';

/// Native Android map only. Running, GPS and route editing belong to their own
/// features. The parent supplies a bounded area for the native platform view.
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
  bool _ready = false;
  bool _mapFailed = false;

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
    if (_mapFailed) {
      return const _MapMessage(message: '지도를 불러오지 못했습니다.');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        KakaoMap(
          option: KakaoMapOption(
            position: widget.initialPosition,
            zoomLevel: widget.zoomLevel,
          ),
          onMapReady: (_) {
            if (mounted) setState(() => _ready = true);
          },
          onMapError: (_) {
            if (mounted) setState(() => _mapFailed = true);
          },
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
