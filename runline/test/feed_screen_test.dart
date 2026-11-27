import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/feed/feed_screen.dart';
import 'package:runline/shared/media/runline_api.dart';
import 'package:runline/shared/media/image_optimizer.dart';
import 'package:runline/shared/media/image_picker_field.dart';

class TestSession extends RunlineAuth {
  bool signedIn = true;
  @override
  bool get isSignedIn => signedIn;
  @override
  String? get accessToken => signedIn ? 'test-token' : null;
  @override
  Future<bool> hasSession() async => signedIn;
  void logout() {
    signedIn = false;
    notifyListeners();
  }
}

Map<String, dynamic> post(String id, String body) => {
  'id': id,
  'body': body,
  'author': {'nickname': '러너'},
  'media': <dynamic>[],
};
http.Response page(List<Map<String, dynamic>> posts, {String? cursor}) =>
    http.Response(
      jsonEncode({'posts': posts, 'nextCursor': cursor}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
RunlineApi apiFor(
  TestSession session,
  Future<http.Response> Function(http.Request) handler,
) => RunlineApi(
  session: session,
  baseUri: Uri.parse('https://api.example.com'),
  client: MockClient(handler),
);

void main() {
  testWidgets('loads main API, retries pagination and switches timeline', (
    tester,
  ) async {
    var calls = 0;
    final api = apiFor(TestSession(), (request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.url.path.endsWith('/following'))
        return page([post('3', '팔로잉 소식')]);
      expect(request.url.path, '/api/v1/feed/recommended');
      calls++;
      if (calls == 1) return page([post('1', '첫 소식')], cursor: 'next+/=');
      expect(request.url.queryParameters['cursor'], 'next+/=');
      if (calls == 2) return http.Response('{"error":{"message":"잠시 후"}}', 500);
      return page([post('1', '첫 소식'), post('2', '다음 소식')]);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('첫 소식'), findsOneWidget);
    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('첫 소식'), findsOneWidget);
    await tester.tap(find.textContaining('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('첫 소식'), findsOneWidget);
    expect(find.text('다음 소식'), findsOneWidget);
    await tester.tap(find.text('팔로잉'));
    await tester.pumpAndSettle();
    expect(find.text('팔로잉 소식'), findsOneWidget);
    expect(find.text('첫 소식'), findsNothing);
  });
  testWidgets('discards pending posts on logout', (tester) async {
    final session = TestSession();
    final pending = Completer<http.Response>();
    final api = apiFor(session, (_) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedScreen(api: api)),
      ),
    );
    await tester.pump();
    session.logout();
    pending.complete(page([post('1', '이전 소식')]));
    await tester.pumpAndSettle();
    expect(find.text('이전 소식'), findsNothing);
    expect(find.textContaining('로그인하면'), findsOneWidget);
  });
  testWidgets('composer posts main body/mediaIds contract and refreshes', (
    tester,
  ) async {
    var created = false;
    final api = apiFor(TestSession(), (request) async {
      if (request.url.path == '/api/v1/feed/media') {
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data;'),
        );
        expect(latin1.decode(request.bodyBytes), contains('name="file"'));
        return http.Response('{"media":{"id":"uploaded-image"}}', 201);
      }
      if (request.method == 'POST') {
        expect(request.url.path, '/api/v1/feed/posts');
        expect(jsonDecode(request.body), {
          'body': '새 소식',
          'mediaIds': ['uploaded-image'],
        });
        created = true;
        return http.Response('{"post":{"id":"new"}}', 201);
      }
      return page(created ? [post('new', '새 소식')] : []);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeedScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('게시글 작성'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '새 소식');
    tester.widget<UploadImagePicker>(find.byType(UploadImagePicker)).onChanged([
      OptimizedUploadImage(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uw0AAAAASUVORK5CYII=',
        ),
        contentType: 'image/png',
        filename: 'image.png',
        width: 1,
        height: 1,
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(find.text('새 소식'), findsOneWidget);
  });
  test('signed media sends token only to API origin', () async {
    final api = apiFor(TestSession(), (request) async {
      expect(request.url.queryParameters['signature'], 'signed');
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response.bytes([1, 2, 3], 200);
    });
    expect(
      await api.imageBytes(
        'https://api.example.com/api/v1/feed/media/id?signature=signed',
      ),
      [1, 2, 3],
    );
    expect(
      () => api.endpoint('https://other.example.com/api/v1/feed/media/id'),
      throwsA(isA<RunlineApiException>()),
    );
  });
}
