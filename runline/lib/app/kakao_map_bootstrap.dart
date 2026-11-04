import 'package:flutter/foundation.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'map_runtime_abi.dart' if (dart.library.ffi) 'map_runtime_abi_ffi.dart';

enum KakaoMapStatus {
  missingKey,
  initialized,
  initializationFailed,
  unsupported,
  unsupportedAbi,
}

/// Initializes the Android map SDK before runApp. Never logs the app key or
/// native exception messages, which may include authentication information.
class KakaoMapBootstrap {
  KakaoMapBootstrap._();

  static KakaoMapStatus _status = KakaoMapStatus.missingKey;

  static KakaoMapStatus get status => _status;

  static Future<void> initialize({
    String nativeAppKey = const String.fromEnvironment('KAKAO_NATIVE_APP_KEY'),
    // Injectable only to exercise device ABI branches in host-side tests.
    String Function() abiProvider = currentMapAbi,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _status = KakaoMapStatus.unsupported;
      return;
    }
    final abi = abiProvider();
    if (abi != 'android_arm64' && abi != 'android_arm') {
      _status = KakaoMapStatus.unsupportedAbi;
      debugPrint('KakaoMap: native initialization disabled for ABI $abi');
      return;
    }
    if (nativeAppKey.trim().isEmpty) {
      _status = KakaoMapStatus.missingKey;
      return;
    }

    try {
      await KakaoMapSdk.instance.initialize(nativeAppKey.trim());
      // Actual map authentication is checked later by onMapReady/onMapError.
      _status = KakaoMapStatus.initialized;
    } catch (_) {
      _status = KakaoMapStatus.initializationFailed;
    }
  }
}
