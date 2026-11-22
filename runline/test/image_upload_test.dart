import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/shared/media/image_optimizer.dart';
import 'package:runline/shared/media/runline_api.dart';

void main() {
  test(
    'all target uploads use authenticated multipart with optimized image bytes',
    () async {
      final session = RunlineSession()..setAccessToken('test-runline-token');
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer test-runline-token');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data;'),
        );
        expect(request.url.query, isEmpty);
        expect(request.bodyBytes, containsAllInOrder([11, 22, 33]));
        return http.Response(
          jsonEncode({
            'ok': true,
            'image': {'id': 'image'},
          }),
          201,
        );
      });
      final api = RunlineApi(
        client: client,
        session: session,
        baseUri: Uri.parse('https://api.example.com'),
      );
      final image = OptimizedUploadImage(
        bytes: Uint8List.fromList([11, 22, 33]),
        contentType: 'image/jpeg',
        filename: 'image.jpg',
        width: 1,
        height: 1,
      );
      for (final path in [
        '/me/avatar',
        '/clubs/club/image',
        '/clubs/club/notices/notice/attachments',
        '/feed/posts/post/images',
      ]) {
        await api.upload(path, image);
      }
      expect(paths, hasLength(4));
    },
  );

  test('web-compatible image fetching carries auth in headers and chooses thumbnails', () async {
    final session = RunlineSession()..setAccessToken('token');
    final api = RunlineApi(
      session: session,
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient((request) async {
        expect(request.url.queryParameters, {'variant': 'thumbnail'});
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
    expect(
      await api.imageBytes('/api/v1/media/images/image', thumbnail: true),
      [1, 2, 3],
    );
  });

  test(
    'external image URLs and unauthenticated uploads never send a request',
    () async {
      var requests = 0;
      final api = RunlineApi(
        session: RunlineSession(),
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.imageBytes('https://attacker.example/image'),
        throwsA(isA<RunlineApiException>()),
      );
      await expectLater(
        api.imageBytes('/api/v1/media/images/image'),
        throwsA(isA<RunlineApiException>()),
      );
      expect(requests, 0);
    },
  );
}
