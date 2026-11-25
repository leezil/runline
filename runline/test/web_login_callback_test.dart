import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/auth/web_login_callback.dart';

void main() {
  final now = DateTime.utc(2026, 11, 24);
  final stored = jsonEncode({
    'state': 'random-state',
    'createdAt': now.millisecondsSinceEpoch,
  });
  Uri callback(String query) =>
      Uri.parse('http://localhost:5000/auth/kakao/callback?$query');
  test('valid state returns code and fixed callback without query', () {
    expect(
      validateWebLoginCallback(
        callback('code=one-time&state=random-state'),
        stored,
        now: now,
      ),
      {
        'code': 'one-time',
        'redirectUri': 'http://localhost:5000/auth/kakao/callback',
      },
    );
  });
  test('missing or mismatched state is rejected', () {
    for (final query in ['code=one-time', 'code=one-time&state=wrong']) {
      expect(
        () => validateWebLoginCallback(callback(query), stored, now: now),
        throwsStateError,
      );
    }
    expect(
      () => validateWebLoginCallback(
        callback('code=x&state=random-state'),
        null,
        now: now,
      ),
      throwsStateError,
    );
  });
  test('expired or future login requests are rejected', () {
    for (final offset in [
      const Duration(minutes: 11),
      const Duration(seconds: -1),
    ]) {
      expect(
        () => validateWebLoginCallback(
          callback('code=x&state=random-state'),
          stored,
          now: now.add(offset),
        ),
        throwsStateError,
      );
    }
  });
  test('cancelled login and missing code are rejected', () {
    for (final query in [
      'state=random-state&error=access_denied',
      'state=random-state',
    ]) {
      expect(
        () => validateWebLoginCallback(callback(query), stored, now: now),
        throwsStateError,
      );
    }
  });
}
