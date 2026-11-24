import 'kakao_sign_in.dart';
import 'runline_auth_api.dart';
import 'runline_session.dart';

abstract interface class TabAuthentication {
  Future<bool> hasSession();
  Future<void> signIn();
}

class RunlineAuth implements TabAuthentication {
  static final shared = RunlineAuth();
  String? get userId => _session?.userId;
  Future<RunlineSession?>? _refreshing;
  Future<RunlineSession?> _refresh(RunlineSession session) =>
      _refreshing ??= _api
          .exchange('refresh', {'refreshToken': session.refreshToken})
          .then((value) {
            if (identical(_session, session)) _session = value;
            return _session;
          })
          .whenComplete(() => _refreshing = null);
  Future<String> tokenFor(String owner) async {
    var session = _session;
    if (session == null || session.userId != owner) {
      throw StateError('Account changed');
    }
    if (!session.accessTokenExpiresAt.isAfter(DateTime.now())) {
      session = await _refresh(session);
    }
    if (session == null || session.userId != owner) {
      throw StateError('Session expired');
    }
    return session.accessToken;
  }

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

    await _refresh(session);
    return _session != null;
  }

  @override
  Future<void> signIn() async {
    final token = await kakaoAccessToken();
    _session = await _api.exchange('kakao', {'accessToken': token});
    if (_session == null) throw StateError('Kakao login was rejected');
  }
}
