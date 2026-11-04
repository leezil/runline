import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/app/kakao_map_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_kakao_maps_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> initializeArm({required String nativeAppKey}) =>
      KakaoMapBootstrap.initialize(
        nativeAppKey: nativeAppKey,
        abiProvider: () => 'android_arm64',
      );

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    await initializeArm(nativeAppKey: '');
  });

  test('empty key skips the native SDK', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      called = true;
      return null;
    });
    await initializeArm(nativeAppKey: '   ');
    expect(KakaoMapBootstrap.status, KakaoMapStatus.missingKey);
    expect(called, isFalse);
  });

  test(
    'passes configuration to the mocked SDK before marking initialized',
    () async {
      // A channel test token, never sent to the actual Kakao SDK.
      const testToken = 'unit-test-input';
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });
      await initializeArm(nativeAppKey: testToken);
      expect(received?.method, 'initialize');
      expect(received?.arguments, {'appKey': testToken});
      expect(KakaoMapBootstrap.status, KakaoMapStatus.initialized);
    },
  );

  test('native initialization error becomes a recoverable map state', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'TEST_FAILURE');
    });
    await initializeArm(nativeAppKey: 'unit-test-input');
    expect(KakaoMapBootstrap.status, KakaoMapStatus.initializationFailed);
  });

  for (final abi in ['android_x64', 'android_ia32', 'unavailable']) {
    test('$abi skips SDK initialization even when a key is supplied', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      await KakaoMapBootstrap.initialize(
        nativeAppKey: 'unit-test-input',
        abiProvider: () => abi,
      );
      expect(KakaoMapBootstrap.status, KakaoMapStatus.unsupportedAbi);
      expect(calls, 0);
    });
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    test('$platform skips both ABI detection and native SDK', () async {
      debugDefaultTargetPlatformOverride = platform;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      await KakaoMapBootstrap.initialize(
        nativeAppKey: 'unit-test-input',
        abiProvider: () => throw StateError('Must not query Android ABI'),
      );
      expect(KakaoMapBootstrap.status, KakaoMapStatus.unsupported);
      expect(calls, 0);
    });
  }
}
