import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/feed/feed_profile_screen.dart';
import 'package:runline/features/feed/feed_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

import 'support/test_runline_auth.dart';

http.Response json(Object value, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json'},
);

class PostServer {
  var body = '수정 전 게시물';
  var exists = true;
  var failMutations = false;
  var listCalls = 0;

  Map<String, dynamic> get post => {
    'id': 'mine',
    'body': body,
    'author': {'id': 'test-user', 'nickname': '달리는 사람', 'avatarUrl': null},
    'media': <dynamic>[],
  };

  late final api = RunlineApi(
    baseUri: Uri.parse('https://api.example.com'),
    session: TestRunlineAuth()..setAccessToken('token'),
    client: MockClient((request) async {
      expectSync(request.headers['Authorization'], 'Bearer token');
      if (request.method != 'GET') {
        if (failMutations) {
          return json({
            'error': {'message': '저장 실패'},
          }, status: 500);
        }
        if (request.method == 'DELETE') {
          expectSync(request.url.path, '/api/v1/feed/posts/mine');
          exists = false;
          return http.Response('', 204);
        }
        expectSync(
          request.url.path,
          request.method == 'POST'
              ? '/api/v1/feed/posts'
              : '/api/v1/feed/posts/mine',
        );
        body = jsonDecode(request.body)['body'] as String;
        exists = true;
        return json({
          'post': post,
        }, status: request.method == 'POST' ? 201 : 200);
      }
      if (request.url.path == '/api/v1/me') {
        return json({
          'profile': {
            'id': 'test-user',
            'nickname': '달리는 사람',
            'avatarUrl': null,
            'followerCount': 0,
            'followingCount': 0,
          },
        });
      }
      expectSync(
        request.url.path,
        anyOf('/api/v1/me/posts', '/api/v1/feed/recommended'),
      );
      listCalls++;
      return json({
        'posts': exists ? [post] : [],
        'nextCursor': null,
      });
    }),
  );
}

void main() {
  for (final profile in [false, true]) {
    final screenName = profile ? 'profile' : 'timeline';
    Future<void> launch(WidgetTester tester, RunlineApi api) async {
      await tester.pumpWidget(
        MaterialApp(
          home: profile
              ? FeedProfileScreen(api: api)
              : Scaffold(body: FeedScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'successful edit, deletion and creation refresh the open $screenName',
      (tester) async {
        final server = PostServer();
        await launch(tester, server.api);
        expect(find.text('수정 전 게시물'), findsOneWidget);

        await server.api.json(
          '/feed/posts/mine',
          method: 'PATCH',
          body: {'body': '수정된 게시물', 'mediaIds': <String>[]},
        );
        await tester.pumpAndSettle();
        expect(find.text('수정된 게시물'), findsOneWidget);
        expect(find.text('수정 전 게시물'), findsNothing);

        await server.api.json('/feed/posts/mine', method: 'DELETE');
        await tester.pumpAndSettle();
        expect(find.text('수정된 게시물'), findsNothing);
        expect(
          find.text(profile ? '아직 작성한 게시물이 없어요.' : '첫 러닝 소식을 남겨보세요.'),
          findsOneWidget,
        );

        await server.api.json(
          '/feed/posts',
          method: 'POST',
          body: {'body': '다시 작성한 게시물', 'mediaIds': <String>[]},
        );
        await tester.pumpAndSettle();
        expect(find.text('다시 작성한 게시물'), findsOneWidget);
        expect(server.listCalls, 4);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed mutations preserve cached posts in the open $screenName',
      (tester) async {
        final server = PostServer()..failMutations = true;
        await launch(tester, server.api);
        for (final method in ['PATCH', 'DELETE', 'POST']) {
          await expectLater(
            server.api.json(
              method == 'POST' ? '/feed/posts' : '/feed/posts/mine',
              method: method,
              body: method == 'DELETE' ? null : {'body': '저장 실패할 내용'},
            ),
            throwsA(isA<RunlineApiException>()),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('수정 전 게시물'), findsOneWidget);
        expect(server.listCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
