import 'dart:convert';

import 'package:http/http.dart' as http;

import 'runline_session.dart';

class RunlineAuthApi {
  const RunlineAuthApi();

  Uri _endpoint(String path) {
    const apiOrigin = String.fromEnvironment('RUNLINE_API_ORIGIN');
    final uri = Uri.tryParse(apiOrigin);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') {
      throw StateError('Set RUNLINE_API_ORIGIN to the Runline API origin');
    }
    return uri.resolve('/api/v1/auth/$path');
  }

  Future<RunlineSession?> exchange(
    String path,
    Map<String, String> payload,
  ) async {
    final response = await http
        .post(
          _endpoint(path),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw StateError('Runline login unavailable');
    }
    return RunlineSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<bool> isValid(String token) async {
    final response = await http
        .get(_endpoint('me'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) return false;
    if (response.statusCode != 200) {
      throw StateError('Runline session check unavailable');
    }
    return true;
  }
}
