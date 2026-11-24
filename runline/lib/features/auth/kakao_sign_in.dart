import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

Future<String> kakaoAccessToken() async {
  const nativeKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  if (nativeKey.isEmpty ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    throw StateError('Kakao sign-in requires a configured Android build');
  }

  await KakaoSdk.init(nativeAppKey: nativeKey);
  final token = await isKakaoTalkInstalled()
      ? await UserApi.instance.loginWithKakaoTalk()
      : await UserApi.instance.loginWithKakaoAccount();
  return token.accessToken;
}
