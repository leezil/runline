# Kakao Map integration (Android and Web)

The route tab's temporary map and the running UI share the same map widget.
GPS, location permissions, running measurements and route editing are not
implemented; the final saved-route list is not part of this integration.

## Native App Key

1. If `config/kakao.local.json` is absent, copy `config/kakao.example.json` to it.
2. Enter your Kakao **Native App Key** as the value of `KAKAO_NATIVE_APP_KEY`
   in `config/kakao.local.json`. The supplied file has an empty value.
3. Keep that local file private. `/config/*.local.json` is ignored by Git.
   Never put real keys in the example, Dart code, Manifest or shared IDE settings.

The file is passed at build time, not bundled as a Flutter asset. Build-time
injection avoids committing the key; it does not make the key impossible to
extract from a built app. Do not print or share the configuration/build arguments.

## Kakao Developers

- Create/select your app and enable Kakao Map usage.
- In the Native App Key's Android settings register `com.example.runline`.
- Register the key hash for this computer's Android debug signing certificate.
  This is Base64(SHA-1(certificate bytes)), not the colon-separated SHA-1 text.
- Other developers' certificates and eventual release/Play signing certificates
  need their own hashes. The phone model does not determine the hash.
- Check the account's current free-quota eligibility before enabling another app.

## Run (PowerShell, from the Flutter project folder)

```powershell
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/kakao.local.json
```

For a supported ARM64 Android phone, enable USB debugging, authorize the PC,
install an OEM USB driver if needed, then replace `DEVICE_ID` below with the
device identifier printed by `flutter devices`:

```powershell
adb -s DEVICE_ID shell getprop ro.product.cpu.abilist
flutter run -d DEVICE_ID --dart-define-from-file=config/kakao.local.json
```

The phone must support `arm64-v8a`, Android API 24+ (the current app minimum),
OpenGL ES 2.0+ and internet access. No location permission is needed for this step.
The current x86_64 emulator is not an officially supported map SDK environment,
even if its ABI list also advertises ARM64 compatibility.

Runline checks the running Dart VM ABI with `Abi.current()` before calling any
Kakao SDK initialization. Only `android_arm64` and `android_arm` are allowed.
On x86/x86_64 (or an unknown Android ABI), it skips both initialization and
`KakaoMap` creation, and shows a message in the existing 300-high map area.
No manual build flag or key-file change is needed to switch devices.
Web uses Kakao Maps JavaScript API through a conditional map export; it never
creates the native KakaoMap. Other platforms retain the existing unsupported
platform message and skip the SDK.

The initial center is the SDK default (Kakao Pangyo campus). Check map display,
pan/zoom, scrolling outside the map, all tabs, and background/resume on the phone.
Changing the key requires stopping and rerunning/rebuilding the app.

Without a key the map area shows a configuration message; other tabs still work.
Initialization/map callback errors show a generic message without exposing key
values. The ABI guard prevents the known x86 native-library crash; Dart error
handling is not used as a substitute for this pre-initialization check.

## Validation

```powershell
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/kakao.local.json
```

An empty key is sufficient for analysis/tests/compilation, but cannot verify
native map authentication or rendering. Tests mock native initialization and
verify that missing keys leave navigation usable. They do not render a real map.

## Web / Chrome

Web platform files were added using `flutter create --platforms=web --no-pub .`.
Android, iOS and desktop platform files must not be regenerated for this setup.

1. Enter your **JavaScript key** in `config/kakao.web.local.json`, as the value
   of `KAKAO_JAVASCRIPT_KEY`. If absent, copy `config/kakao.web.example.json`.
   The supplied local/example files contain an empty value. Do not use the
   Native App Key here, and do not pass the Android config to a web build.
2. In Kakao Developers select the app, then **[앱 설정] > [앱] > [플랫폼 키]**,
   select the JavaScript key, and register **`http://localhost:8080`** as a
   JavaScript SDK domain. In [카카오맵] > [사용 설정], confirm [상태] is ON.
   Keep existing Android settings and key hashes unchanged.
3. Run from this Flutter project folder:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=8080 --dart-define-from-file=config/kakao.web.local.json
```

Use exactly `http://localhost:8080`. If using `127.0.0.1` instead, separately
register `http://127.0.0.1:8080`. Deployment requires the actual HTTPS origin
to be registered too. Domains must match scheme, host and port; no app route
or callback path is needed for maps. Do not bypass domain restrictions.

```powershell
flutter analyze
flutter test
flutter test --platform chrome test/web_map_test.dart
flutter build web --dart-define-from-file=config/kakao.web.local.json
```

`/config/*.local.json` is already ignored by Git. Do not print the key or SDK
URL. A browser JavaScript key is visible in built client code/network requests;
the local file prevents Git exposure, and registered domains restrict usage.
The Android key is supplied only to Android builds.

Both the route tab's 300-high map and the running screen reuse RunlineMapView.
The web implementation dynamically loads the official SDK once, uses a DOM
platform view, supports dragging and wheel zoom, and relayouts on resize/tab
visibility changes. Initial center matches the Android map default.

Without a JavaScript key, each map shows a configuration message without
requesting Kakao scripts. Load failure/timeout shows a generic key/domain/network
message. After changing the key, stop and rebuild/restart the app; after an SDK
load failure, reload the page. Actual tiles, drag and zoom require a valid key
and registered domain and must be checked manually in both screens. No GPS,
Geolocation, permissions, polylines or running measurements are added.

Official references:
- https://docs.flutter.dev/platform-integration/web/building
- https://apis.map.kakao.com/web/guide/
- https://developers.kakao.com/docs/ko/kakaomap/common
