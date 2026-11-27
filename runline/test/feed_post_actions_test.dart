import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/feed/feed_post_screen.dart';
import 'package:runline/features/feed/feed_profile_screen.dart';
import 'package:runline/shared/media/image_compose_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

class ActionSession extends RunlineAuth {
  String? account = 'owner';
  int revision = 0;

  @override
  bool get isSignedIn => account != null;
  @override
  String? get userId => account;
  @override
  String? get accessToken => account == null ? null : '$account-$revision';
  @override
  Future<bool> hasSession() async => isSignedIn;

  void switchAccount(String? value) {
    account = value;
    notifyListeners();
  }

  void rotateToken() {
    revision++;
    notifyListeners();
  }
}

http.Response json(Object data, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

class PostServer {
  final session = ActionSession();
  String author = 'owner';
  String body = '수정 전 러닝 소식';
  bool deleted = false;
  bool failDelete = false;
  int reads = 0;
  int deletions = 0;
  final updates = <Map<String, dynamic>>[];
  Completer<http.Response>? pendingDeletion;

  Map<String, dynamic> get post => {
    'id': 'post',
    'body': body,
    'author': {'id': author, 'nickname': '작성자', 'avatarUrl': null},
    'media': <dynamic>[],
  };

  late final api = RunlineApi(
    session: session,
    baseUri: Uri.parse('https://api.example.com'),
    client: MockClient((request) async {
      expectSync(
        request.headers['Authorization'],
        'Bearer ${session.accessToken}',
      );
      switch (request.url.path) {
        case '/api/v1/me':
          return json({
            'profile': {
              'id': session.userId,
              'nickname': '내 이름',
              'avatarUrl': null,
              'bio': '',
              'followerCount': 0,
              'followingCount': 0,
              'isFollowing': false,
            },
          });
        case '/api/v1/me/posts':
          return json({
            'posts': deleted ? [] : [post],
            'nextCursor': null,
          });
        case '/api/v1/feed/posts/post':
          if (request.method == 'DELETE') {
            deletions++;
            final response = pendingDeletion == null
                ? failDelete
                      ? json({
                          'error': {'message': '삭제를 다시 시도해주세요.'},
                        }, status: 500)
                      : http.Response('', 204)
                : await pendingDeletion!.future;
            if (response.statusCode == 204) deleted = true;
            return response;
          }
          if (request.method == 'PATCH') {
            final update = jsonDecode(request.body) as Map<String, dynamic>;
            updates.add(update);
            body = update['body'] as String;
            return json({'post': post});
          }
          reads++;
          return deleted
              ? json({
                  'error': {'message': '게시글을 찾을 수 없어요.'},
                }, status: 404)
              : json({'post': post});
        default:
          throw StateError(
            'Unexpected request: ${request.method} ${request.url}',
          );
      }
    }),
  );
}

Future<void> launchDetail(WidgetTester tester, PostServer server) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => FeedPostScreen(postId: 'post', api: server.api),
              ),
            ),
            child: const Text('게시글 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('게시글 열기'));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('게시글 메뉴'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  for (final own in [true, false]) {
    testWidgets(
      'post menu is ${own ? 'shown for its owner' : 'hidden for other users'}',
      (tester) async {
        final server = PostServer()..author = own ? 'owner' : 'another';
        await launchDetail(tester, server);
        expect(find.byTooltip('게시글 메뉴'), own ? findsOneWidget : findsNothing);
        if (own) {
          await tester.tap(find.byTooltip('게시글 메뉴'));
          await tester.pumpAndSettle();
          expect(find.text('게시글 수정'), findsOneWidget);
          expect(find.text('게시글 삭제'), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'edit opens the existing content and refreshes detail after saving',
    (tester) async {
      final server = PostServer();
      await launchDetail(tester, server);
      await choose(tester, '게시글 수정');
      expect(find.byType(ImageComposeScreen), findsOneWidget);
      expect(find.text('게시글 수정'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '수정 전 러닝 소식',
      );
      await tester.enterText(find.byType(TextField), '수정한 러닝 소식');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(server.updates, [
        {'body': '수정한 러닝 소식', 'mediaIds': []},
      ]);
      expect(server.reads, greaterThanOrEqualTo(2));
      expect(find.byType(ImageComposeScreen), findsNothing);
      expect(find.text('수정한 러닝 소식'), findsOneWidget);
      expect(find.text('수정 전 러닝 소식'), findsNothing);
    },
  );

  testWidgets('cancelling deletion leaves the post intact without a request', (
    tester,
  ) async {
    final server = PostServer();
    await launchDetail(tester, server);
    await choose(tester, '게시글 삭제');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(server.deletions, 0);
    expect(find.text('수정 전 러닝 소식'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'confirmed deletion returns to own profile and removes its grid item',
    (tester) async {
      final server = PostServer();
      await tester.pumpWidget(
        MaterialApp(home: FeedProfileScreen(api: server.api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-post-post')));
      await tester.pumpAndSettle();
      await choose(tester, '게시글 삭제');
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(server.deletions, 1);
      expect(server.deleted, isTrue);
      expect(find.byType(FeedPostScreen), findsNothing);
      expect(find.byKey(const ValueKey('profile-post-post')), findsNothing);
      expect(find.text('아직 작성한 게시물이 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed deletion retains the post and lets the owner retry', (
    tester,
  ) async {
    final server = PostServer()..failDelete = true;
    await launchDetail(tester, server);
    await choose(tester, '게시글 삭제');
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(server.deletions, 1);
    expect(find.byType(FeedPostScreen), findsOneWidget);
    expect(find.text('수정 전 러닝 소식'), findsOneWidget);
    expect(find.text('삭제를 다시 시도해주세요.'), findsOneWidget);
    server.failDelete = false;
    await choose(tester, '게시글 삭제');
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(server.deletions, 2);
    expect(find.byType(FeedPostScreen), findsNothing);
    expect(find.text('게시글 열기'), findsOneWidget);
  });

  testWidgets(
    'pending deletion prevents duplicate submission and back navigation',
    (tester) async {
      final pending = Completer<http.Response>();
      final server = PostServer()..pendingDeletion = pending;
      await launchDetail(tester, server);
      await choose(tester, '게시글 삭제');
      await tester.tap(find.text('삭제'));
      await tester.pump();
      expect(server.deletions, 1);
      final menu = find.byWidgetPredicate(
        (widget) => widget is PopupMenuButton,
      );
      expect(tester.widget<PopupMenuButton>(menu).enabled, isFalse);
      await tester.tap(find.text('작성자'));
      await tester.pump();
      expect(find.byType(FeedProfileScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(FeedPostScreen), findsOneWidget);
      expect(server.deletions, 1);
      pending.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(find.byType(FeedPostScreen), findsNothing);
      expect(server.deletions, 1);
    },
  );

  testWidgets(
    'logging out while the confirmation is open cannot delete a post',
    (tester) async {
      final server = PostServer();
      await launchDetail(tester, server);
      await choose(tester, '게시글 삭제');
      server.session.switchAccount(null);
      await tester.pumpAndSettle();
      if (find.text('삭제').evaluate().isNotEmpty) {
        await tester.tap(find.text('삭제'));
        await tester.pumpAndSettle();
      }
      expect(server.deletions, 0);
      expect(find.byTooltip('게시글 메뉴'), findsNothing);
      expect(find.byType(FeedPostScreen), findsOneWidget);
    },
  );

  testWidgets(
    'an old account deletion response cannot pop the current account screen',
    (tester) async {
      final pending = Completer<http.Response>();
      final server = PostServer()..pendingDeletion = pending;
      await launchDetail(tester, server);
      await choose(tester, '게시글 삭제');
      await tester.tap(find.text('삭제'));
      await tester.pump();
      server.session.switchAccount('another');
      await tester.pump();
      pending.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(server.deletions, 1);
      expect(find.byType(FeedPostScreen), findsOneWidget);
      expect(find.byTooltip('게시글 메뉴'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-account token rotation does not discard a successful deletion',
    (tester) async {
      final pending = Completer<http.Response>();
      final server = PostServer()..pendingDeletion = pending;
      await launchDetail(tester, server);
      await choose(tester, '게시글 삭제');
      await tester.tap(find.text('삭제'));
      await tester.pump();
      server.session.rotateToken();
      await tester.pump();
      pending.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(server.deletions, 1);
      expect(find.byType(FeedPostScreen), findsNothing);
      expect(find.text('게시글 열기'), findsOneWidget);
    },
  );
}
