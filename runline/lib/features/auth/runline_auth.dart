import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kakao_sign_in.dart';
import 'runline_auth_api.dart';
import 'runline_session.dart';
import 'session_storage.dart';
import 'web_test_login.dart';

abstract interface class TabAuthentication {
  Future<bool> hasSession();
  Future<void> signIn();
}

class RunlineAuth extends ChangeNotifier implements TabAuthentication {
  RunlineAuth({RunlineAuthApi? api, SessionStorage? storage})
    : _api = api ?? const RunlineAuthApi(),
      _storage = storage ?? const SecureSessionStorage();

  static final instance = RunlineAuth();
  final RunlineAuthApi _api;
  final SessionStorage _storage;
  RunlineSession? _session;
  bool _loaded = false;
  Future<void>? _pending;
  Future<bool>? _checkingSession;

  // Serialize restore, refresh, login and logout so an older response cannot
  // overwrite a newly rotated token or resurrect a logged-out session.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final previous = _pending;
    final result = previous == null
        ? operation()
        : previous.then((_) => operation());
    late final Future<void> pending;
    pending = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_pending, pending)) _pending = null;
        });
    _pending = pending;
    return result;
  }

  String? get accessToken => _session?.accessToken;
  bool get isSignedIn => _session != null;
  String? get userId => _session?.userId;

  Future<void> _load() async {
    if (_loaded) return;
    final value = await _storage.read();
    if (value != null) {
      try {
        _session = RunlineSession.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
      } on FormatException {
        await _storage.clear();
      } on TypeError {
        await _storage.clear();
      }
    }
    _loaded = true;
  }

  Future<void> _save(RunlineSession? value) async {
    if (value == null) {
      await _storage.clear();
    } else {
      await _storage.write(jsonEncode(value.toJson()));
    }
    _session = value;
    notifyListeners();
  }

  Future<void> _refresh(RunlineSession session) async {
    // Only a definitive 401 clears credentials. Transport/server errors propagate
    // without deleting the saved session, allowing a later retry.
    final value = await _api.exchange('refresh', {
      'refreshToken': session.refreshToken,
    });
    await _save(value);
  }

  @override
  Future<bool> hasSession() => _checkingSession ??= _serial(() async {
    await _load();
    final session = _session;
    if (session == null) return false;
    if (session.accessTokenExpiresAt.isAfter(DateTime.now()) &&
        await _api.isValid(session.accessToken)) {
      return true;
    }
    await _refresh(session);
    return _session != null;
  }).whenComplete(() => _checkingSession = null);

  Future<String> tokenFor(String owner) => _serial(() async {
    await _load();
    var session = _session;
    if (session == null || session.userId != owner) {
      throw StateError('Account changed');
    }
    if (!session.accessTokenExpiresAt.isAfter(DateTime.now())) {
      await _refresh(session);
      session = _session;
    }
    if (session == null || session.userId != owner) {
      throw StateError('Session expired');
    }
    return session.accessToken;
  });

  @override
  Future<void> signIn() => _serial(() async {
    final RunlineSession? value;
    if (kIsWeb) {
      value = await _api.exchange('kakao/web', consumeWebLoginCallback());
    } else {
      final token = await kakaoAccessToken();
      value = await _api.exchange('kakao', {'accessToken': token});
    }
    if (value == null) throw StateError('Kakao login was rejected');
    await _save(value);
    _loaded = true;
  });

  Future<void> signOut() => _serial(() async {
    await _load();
    final session = _session;
    // Keep the session on failure so logout can be retried and server revocation
    // is never silently skipped.
    if (session != null) await _api.logout(session.refreshToken);
    await _save(null);
  });
}
