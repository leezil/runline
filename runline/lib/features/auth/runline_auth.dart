import 'package:flutter/foundation.dart';

import 'kakao_sign_in.dart';
import 'runline_auth_api.dart';
import 'runline_session.dart';
import 'web_test_login.dart';

abstract interface class TabAuthentication {
  Future<bool> hasSession();
  Future<void> signIn();
}

class RunlineAuth extends ChangeNotifier implements TabAuthentication {
  static final instance = RunlineAuth();

  String? get accessToken => _session?.accessToken;
  bool get isSignedIn => _session != null;
  final _api = const RunlineAuthApi();
  RunlineSession? _session;
  Future<bool>? _checkingSession;

  @override
  Future<bool> hasSession() => _checkingSession ??= _validateSession()
      .whenComplete(() => _checkingSession = null);

  Future<bool> _validateSession() async {
    final session = _session;
    if (session == null) return false;

    if (session.accessTokenExpiresAt.isAfter(DateTime.now()) &&
        await _api.isValid(session.accessToken)) {
      return true;
    }

    final refreshed = await _api.exchange('refresh', {
      'refreshToken': session.refreshToken,
    });
    _session = refreshed;
    notifyListeners();
    return _session != null;
  }

  @override
  Future<void> signIn() async {
    if (kIsWeb) {
      _session = await _api.exchange('kakao/web', consumeWebLoginCallback());
    } else {
      final token = await kakaoAccessToken();
      _session = await _api.exchange('kakao', {'accessToken': token});
    }
    if (_session == null) throw StateError('Kakao login was rejected');
    notifyListeners();
  }
}
