import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../features/auth/runline_auth.dart';
import 'image_optimizer.dart';

class RunlineApiException implements Exception {
  const RunlineApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => message;
}

class RunlineApi {
  RunlineApi({http.Client? client, RunlineAuth? session, Uri? baseUri})
    : _client = client ?? http.Client(),
      session = session ?? RunlineAuth.instance,
      baseUri =
          baseUri ??
          Uri.parse(const String.fromEnvironment('RUNLINE_API_ORIGIN'));

  static final instance = RunlineApi();
  final http.Client _client;
  final RunlineAuth session;
  final Uri baseUri;
  final _profileRevision = ValueNotifier<int>(0);
  final _postsRevision = ValueNotifier<int>(0);
  Listenable get profileChanges => _profileRevision;
  Listenable get postsChanges => _postsRevision;

  void notifyProfileChanged() => _profileRevision.value++;

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
    final uri = baseUri.resolveUri(relative);
    if (uri.origin != baseUri.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !uri.path.startsWith('/api/v1/')) {
      throw const RunlineApiException('올바르지 않은 이미지 주소예요.');
    }
    return uri;
  }

  Future<Map<String, String>> _headers() async {
    final owner = session.userId;
    if (!await session.hasSession()) {
      throw const RunlineApiException('로그인 후 이용해주세요.', statusCode: 401);
    }
    if (owner != null && owner != session.userId) {
      throw const RunlineApiException(
        '계정이 변경되었어요. 다시 시도해주세요.',
        statusCode: 401,
      );
    }
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
    final owner = session.userId;
    final request = http.Request(method, endpoint('/api/v1$path'));
    request.followRedirects = false;
    request.headers.addAll(await _headers());
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 45)),
    );
    final result = response.statusCode == 204
        ? <String, dynamic>{}
        : _decode(response);
    if (session.isSignedIn && session.userId == owner) {
      if (method == 'PATCH' && path == '/me/profile') {
        notifyProfileChanged();
      }
      if ((method == 'POST' && path == '/feed/posts') ||
          ((method == 'PATCH' || method == 'DELETE') &&
              RegExp(r'^/feed/posts/[^/?#]+$').hasMatch(path))) {
        _postsRevision.value++;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> upload(
    String path,
    OptimizedUploadImage image,
  ) => uploadFile(
    path,
    image.bytes,
    filename: image.filename,
    contentType: image.contentType,
  );

  Future<Map<String, dynamic>> uploadFile(
    String path,
    Uint8List bytes, {
    required String filename,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const RunlineApiException('파일은 1바이트~5MB까지 올릴 수 있어요.');
    }
    final owner = session.userId;
    final request = http.MultipartRequest('POST', endpoint('/api/v1$path'));
    request.followRedirects = false;
    request.headers.addAll(await _headers());
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 60)),
    );
    final result = _decode(response);
    if (path == '/me/avatar' && session.isSignedIn && session.userId == owner) {
      notifyProfileChanged();
    }
    return result;
  }

  Future<Uint8List> imageBytes(String path, {bool thumbnail = false}) async {
    var uri = endpoint(path);
    if (thumbnail && uri.path.startsWith('/api/v1/media/images/')) {
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, 'variant': 'thumbnail'},
      );
    }
    final request = http.Request('GET', uri);
    request.followRedirects = false;
    request.headers.addAll(await _headers());
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 30)),
    );
    if (response.statusCode != 200) {
      _decode(response);
      throw const RunlineApiException('사진을 불러오지 못했어요.');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> fileBytes(String path) async {
    final request = http.Request('GET', endpoint(path));
    request.followRedirects = false;
    request.headers.addAll(await _headers());
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 45)),
    );
    if (response.statusCode != 200) {
      _decode(response);
      throw const RunlineApiException('파일을 불러오지 못했어요.');
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = switch (response.statusCode) {
        401 => '로그인 후 이용해주세요.',
        403 => '이 작업을 수행할 권한이 없어요.',
        413 => '사진 용량이 너무 커요. 다른 사진을 선택해주세요.',
        503 => '이미지 업로드를 준비 중이에요. 잠시 후 다시 시도해주세요.',
        _ => result['error']?['message'] as String? ?? '요청을 처리하지 못했어요.',
      };
      throw RunlineApiException(
        message,
        statusCode: response.statusCode,
        code: result['error']?['code'] as String?,
      );
    }
    return result;
  }
}
