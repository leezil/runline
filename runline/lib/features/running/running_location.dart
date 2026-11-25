import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum GpsStatus {
  connecting,
  tracking,
  weak,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
  paused,
  finished,
}

class GpsPoint {
  const GpsPoint(this.latitude, this.longitude, this.accuracy, this.timestamp);
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
}

abstract interface class RunningLocation {
  /// Null means permission and service checks succeeded.
  Future<GpsStatus?> prepare();
  Stream<GpsPoint> positions();
}

bool get supportsBackgroundRunning =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class GeolocatorRunningLocation implements RunningLocation {
  @override
  Future<GpsStatus?> prepare() async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return GpsStatus.unavailable;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return GpsStatus.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.denied => GpsStatus.denied,
      LocationPermission.deniedForever => GpsStatus.deniedForever,
      // Browsers without Permissions API can still request a position.
      LocationPermission.unableToDetermine when !kIsWeb =>
        GpsStatus.unavailable,
      _ => null,
    };
  }

  @override
  Stream<GpsPoint> positions() => Geolocator.getPositionStream(
    locationSettings: supportsBackgroundRunning
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            intervalDuration: const Duration(seconds: 1),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationChannelName: '러닝 기록',
              notificationTitle: 'Runline · 러닝 기록 중',
              notificationText: '화면이 꺼져도 이동 경로를 기록해요.',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
          ),
  ).map((p) => GpsPoint(p.latitude, p.longitude, p.accuracy, p.timestamp));
}
