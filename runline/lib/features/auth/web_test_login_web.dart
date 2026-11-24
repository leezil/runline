import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_login_callback.dart';

// WEB_TEST_LOGIN: default OFF; release builds are always blocked.
bool get webTestLoginEnabled =>
    !kReleaseMode && const bool.fromEnvironment('ENABLE_WEB_TEST_LOGIN');
const _storageKey = 'runline.web-test-login.state';
const _callbackPath = '/auth/kakao/callback';
bool get hasWebLoginCallback =>
    webTestLoginEnabled && Uri.base.path == _callbackPath;

void startWebTestLogin() {
  if (!webTestLoginEnabled) throw StateError('웹 테스트 로그인이 비활성화되어 있습니다.');
  const key = String.fromEnvironment('KAKAO_REST_API_KEY');
  if (key.isEmpty) throw StateError('웹 로그인 설정을 확인해주세요.');
  final state = base64UrlEncode(
    List.generate(32, (_) => Random.secure().nextInt(256)),
  );
  web.window.sessionStorage.setItem(
    _storageKey,
    jsonEncode({
      'state': state,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }),
  );
  web.window.location.assign(
    Uri.https('kauth.kakao.com', '/oauth/authorize', {
      'response_type': 'code',
      'client_id': key,
      'redirect_uri': '${Uri.base.origin}$_callbackPath',
      'state': state,
    }).toString(),
  );
}

Map<String, String> consumeWebLoginCallback() {
  if (!hasWebLoginCallback) throw StateError('웹 테스트 로그인이 비활성화되어 있습니다.');
  final callback = Uri.base;
  final stored = web.window.sessionStorage.getItem(_storageKey);
  web.window.sessionStorage.removeItem(_storageKey);
  // Remove one-time code/state from browser history before exchanging them.
  web.window.history.replaceState(null, '', '/');
  return validateWebLoginCallback(callback, stored);
}
