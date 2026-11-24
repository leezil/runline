import 'kakao_sign_in.dart';
import 'runline_auth_api.dart';
import 'runline_session.dart';

abstract interface class TabAuthentication {
  Future<bool> hasSession();
  Future<void> signIn();
}

class RunlineAuth implements TabAuthentication {
  final _api = const RunlineAuthApi();
  RunlineSession? _session;

  @override
  Future<bool> hasSession() async {
    final session = _session;
    if (session == null) return false;

    if (session.accessTokenExpiresAt.isAfter(DateTime.now()) &&
        await _api.isValid(session.accessToken)) {
      return true;
    }

    _session = await _api.exchange('refresh', {
      'refreshToken': session.refreshToken,
    });
    return _session != null;
  }

  @override
  Future<void> signIn() async {
    final token = await kakaoAccessToken();
    _session = await _api.exchange('kakao', {'accessToken': token});
    if (_session == null) throw StateError('Kakao login was rejected');
  }
}
