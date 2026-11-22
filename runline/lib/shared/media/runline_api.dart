import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'image_optimizer.dart';

class RunlineApiException implements Exception {
  const RunlineApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// The login flow supplies a RUNLINE access token here after Kakao exchange.
/// Tokens never appear in image URLs, build-time constants or browser storage.
class RunlineSession extends ChangeNotifier {
  static final instance = RunlineSession();
  String? _accessToken;
  String? get accessToken => _accessToken;
  bool get isSignedIn => _accessToken?.isNotEmpty == true;
  void setAccessToken(String? token) {
    _accessToken = token;
    notifyListeners();
  }
}

class RunlineApi {
  RunlineApi({http.Client? client, RunlineSession? session, Uri? baseUri})
    : _client = client ?? http.Client(),
      session = session ?? RunlineSession.instance,
      baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'RUNLINE_API_BASE_URL',
              defaultValue: 'http://localhost:8787',
            ),
          );

  static final instance = RunlineApi();
  final http.Client _client;
  final RunlineSession session;
  final Uri baseUri;

  Uri endpoint(String path) {
    if (baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        (baseUri.scheme != 'https' &&
            !(baseUri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '::1'].contains(baseUri.host)))) {
      throw const RunlineApiException('서버 주소를 확인해주세요.');
    }
    final relative = Uri.parse(path);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        !path.startsWith('/api/v1/')) {
      throw const RunlineApiException('올바르지 않은 이미지 주소예요.');
    }
    return baseUri.replace(
      path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}${relative.path}',
      query: relative.hasQuery ? relative.query : null,
    );
  }

  Map<String, String> _headers() {
    final token = session.accessToken;
    if (token == null || token.isEmpty) {
      throw const RunlineApiException('로그인 후 이용해주세요.', statusCode: 401);
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> json(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, endpoint('/api/v1$path'));
    request.headers.addAll(_headers());
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 45)),
    );
    if (response.statusCode == 204) return {};
    return _decode(response);
  }

  Future<Map<String, dynamic>> upload(
    String path,
    OptimizedUploadImage image,
  ) async {
    final request = http.MultipartRequest('POST', endpoint('/api/v1$path'));
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        image.bytes,
        filename: image.filename,
        contentType: MediaType.parse(image.contentType),
      ),
    );
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 60)),
    );
    return _decode(response);
  }

  Future<Uint8List> imageBytes(String path, {bool thumbnail = false}) async {
    var uri = endpoint(path);
    if (thumbnail) {
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, 'variant': 'thumbnail'},
      );
    }
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      _decode(response);
      throw const RunlineApiException('사진을 불러오지 못했어요.');
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> result;
    try {
      result =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const RunlineApiException('서버 응답을 확인하지 못했어요.');
    }
    if (response.statusCode >= 400) {
      final message = switch (response.statusCode) {
        401 => '로그인 후 이용해주세요.',
        403 => '이 작업을 수행할 권한이 없어요.',
        413 => '사진 용량이 너무 커요. 다른 사진을 선택해주세요.',
        503 => '이미지 업로드를 준비 중이에요. 잠시 후 다시 시도해주세요.',
        _ => result['error']?['message'] as String? ?? '요청을 처리하지 못했어요.',
      };
      throw RunlineApiException(message, statusCode: response.statusCode);
    }
    return result;
  }
}
