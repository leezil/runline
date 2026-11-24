import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/feed/feed_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

Map<String, dynamic> post(String id) => {
  'id': id,
  'nickname': null,
  'title': 'post $id',
  'content': '',
  'images': <dynamic>[],
};
http.Response page(List<Map<String, dynamic>> items, [String? cursor]) =>
    http.Response(
      jsonEncode({'ok': true, 'items': items, 'nextCursor': cursor}),
      200,
    );

void main() {
  testWidgets(
    'authenticated pagination retries cursor and removes duplicates',
    (tester) async {
      final session = RunlineSession()..setAccessToken('token');
      var calls = 0;
      final api = RunlineApi(
        session: session,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          expect(request.url.path, '/api/v1/feed/posts');
          calls++;
          if (calls == 1) return page([post('1')], 'a+/=');
          expect(request.url.queryParameters['cursor'], 'a+/=');
          if (calls == 2) {
            return http.Response('{"error":{"message":"failed"}}', 500);
          }
          return page([post('1'), post('2')]);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('러너'), findsOneWidget);
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('post 1'), findsOneWidget);
      expect(find.text('post 2'), findsOneWidget);
      expect(find.text('더 보기'), findsNothing);
      session.setAccessToken(null);
      await tester.pumpAndSettle();
      expect(find.text('post 1'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '게시글 작성',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'composer posts with same authenticated client and reloads feed',
    (tester) async {
      final session = RunlineSession()..setAccessToken('token');
      var created = false;
      final api = RunlineApi(
        session: session,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.method == 'POST') {
            expect(request.url.path, '/api/v1/feed/posts');
            expect(jsonDecode(request.body), {
              'title': 'new title',
              'content': 'running',
            });
            created = true;
            return http.Response('{"ok":true,"post":{"id":"new"}}', 201);
          }
          return page(created ? [post('new')] : []);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('게시글 작성'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'new title');
      await tester.enterText(find.byType(TextFormField).at(1), 'running');
      await tester.ensureVisible(find.text('저장'));
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(find.text('post new'), findsOneWidget);
    },
  );
}
