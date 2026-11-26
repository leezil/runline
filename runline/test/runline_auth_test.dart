import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/auth/runline_auth_api.dart';
import 'package:runline/features/auth/runline_session.dart';
import 'package:runline/features/auth/session_storage.dart';

class Store implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}

RunlineSession makeSession(String token, int minutes) => RunlineSession(
  userId: 'runner',
  accessToken: token,
  refreshToken: 'refresh-$token',
  accessTokenExpiresAt: DateTime.now().add(Duration(minutes: minutes)),
);

class Api extends RunlineAuthApi {
  bool offline = false;
  RunlineSession? next = makeSession('new', 15);
  int refreshes = 0;
  String? revoked;
  @override
  Future<bool> isValid(String token) async {
    if (offline) throw StateError('offline');
    return true;
  }

  @override
  Future<RunlineSession?> exchange(
    String path,
    Map<String, String> payload,
  ) async {
    refreshes++;
    if (offline) throw StateError('offline');
    return next;
  }

  @override
  Future<void> logout(String token) async {
    if (offline) throw StateError('offline');
    revoked = token;
  }
}

void main() {
  late Store store;
  late Api api;
  late RunlineAuth auth;
  setUp(() {
    store = Store()..value = jsonEncode(makeSession('old', -1).toJson());
    api = Api();
    auth = RunlineAuth(api: api, storage: store);
  });
  test('restore rotates tokens and persists across restarts', () async {
    expect(await auth.hasSession(), isTrue);
    final restarted = RunlineAuth(api: api, storage: store);
    expect(await restarted.hasSession(), isTrue);
    expect(restarted.accessToken, 'new');
    expect(restarted.userId, 'runner');
    expect(api.refreshes, 1);
  });
  test('concurrent checks perform one refresh', () async {
    expect(await Future.wait([auth.hasSession(), auth.hasSession()]), [
      true,
      true,
    ]);
    expect(api.refreshes, 1);
  });
  test('invalid refresh clears saved credentials', () async {
    api.next = null;
    expect(await auth.hasSession(), isFalse);
    expect(store.value, isNull);
  });
  test('network failure retains credentials for retry', () async {
    final saved = store.value;
    api.offline = true;
    await expectLater(auth.hasSession(), throwsStateError);
    expect(store.value, saved);
    api.offline = false;
    expect(await auth.hasSession(), isTrue);
  });
  test('logout after concurrent refresh revokes latest token', () async {
    final checking = auth.hasSession();
    final logout = auth.signOut();
    await checking;
    await logout;
    expect(api.revoked, 'refresh-new');
    expect(store.value, isNull);
    expect(auth.isSignedIn, isFalse);
    expect(await RunlineAuth(api: api, storage: store).hasSession(), isFalse);
  });
  test('failed logout preserves revocation token for retry', () async {
    await auth.hasSession();
    api.offline = true;
    await expectLater(auth.signOut(), throwsStateError);
    expect(store.value, isNotNull);
    api.offline = false;
    await auth.signOut();
    expect(api.revoked, 'refresh-new');
    expect(store.value, isNull);
  });
}
