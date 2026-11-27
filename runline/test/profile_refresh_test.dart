import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/feed/feed_post_screen.dart';
import 'package:runline/features/feed/feed_screen.dart';
import 'package:runline/features/feed/widgets/feed_avatar.dart';
import 'package:runline/shared/media/runline_api.dart';

import 'support/test_runline_auth.dart';

void main() {
  for (final detail in [false, true]) {
    testWidgets(
      'saved name and photo refresh the open ${detail ? 'post' : 'feed'}',
      (tester) async {
        var name = '수정 전 이름';
        String? avatarUrl;
        final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uw0AAAAASUVORK5CYII=',
        );
        http.Response json(Map<String, dynamic> body) => http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        final api = RunlineApi(
          session: TestRunlineAuth()..setAccessToken('profile-token'),
          baseUri: Uri.parse('https://api.example.com'),
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/me/profile') {
              expectSync(request.method, 'PATCH');
              name = jsonDecode(request.body)['nickname'] as String;
              return json({
                'profile': {'nickname': name},
              });
            }
            if (request.url.path == '/api/v1/me/avatar') {
              expectSync(request.method, 'POST');
              avatarUrl = '/api/v1/media/images/avatar';
              return json({
                'image': {'url': avatarUrl},
              });
            }
            if (request.url.path == '/api/v1/media/images/avatar') {
              return http.Response.bytes(png, 200);
            }
            final post = {
              'id': 'post',
              'body': '저장된 러닝 소식',
              'author': {
                'id': 'test-user',
                'nickname': name,
                'avatarUrl': avatarUrl,
              },
              'media': <dynamic>[],
            };
            expectSync(
              request.url.path,
              detail ? '/api/v1/feed/posts/post' : '/api/v1/feed/recommended',
            );
            return json(
              detail
                  ? {'post': post}
                  : {
                      'posts': [post],
                      'nextCursor': null,
                    },
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: detail
                ? FeedPostScreen(postId: 'post', api: api)
                : Scaffold(body: FeedScreen(api: api)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('수정 전 이름'), findsOneWidget);

        await api.json(
          '/me/profile',
          method: 'PATCH',
          body: {'nickname': '변경한 이름'},
        );
        await tester.pumpAndSettle();
        expect(find.text('변경한 이름'), findsOneWidget);
        expect(find.text('수정 전 이름'), findsNothing);

        await api.uploadFile(
          '/me/avatar',
          png,
          filename: 'avatar.png',
          contentType: 'image/png',
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<FeedAvatar>(find.byType(FeedAvatar)).avatarUrl,
          '/api/v1/media/images/avatar',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
