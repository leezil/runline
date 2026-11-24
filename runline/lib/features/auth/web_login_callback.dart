import 'dart:convert';

Map<String, String> validateWebLoginCallback(
  Uri callback,
  String? stored, {
  DateTime? now,
}) {
  if (stored == null) throw StateError('로그인을 다시 시작해주세요.');
  final pending = jsonDecode(stored) as Map<String, dynamic>;
  final age =
      (now ?? DateTime.now()).millisecondsSinceEpoch -
      (pending['createdAt'] as int);
  if (age < 0 ||
      age > 10 * 60 * 1000 ||
      pending['state'] is! String ||
      (pending['state'] as String).isEmpty ||
      callback.queryParameters['state'] != pending['state']) {
    throw StateError('로그인 요청이 만료되었거나 일치하지 않습니다. 다시 시도해주세요.');
  }
  final code = callback.queryParameters['code'];
  if (callback.queryParameters.containsKey('error') ||
      code == null ||
      code.isEmpty) {
    throw StateError('카카오 로그인이 취소되었거나 실패했습니다.');
  }
  return {
    'code': code,
    'redirectUri': '${callback.origin}/auth/kakao/callback',
  };
}
