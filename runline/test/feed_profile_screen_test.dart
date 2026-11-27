import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/feed/feed_profile_screen.dart';
import 'package:runline/features/feed/feed_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

class ProfileSession extends RunlineAuth {
  bool active = true;
  @override
  bool get isSignedIn => active;
  @override
  String? get accessToken => active ? 'profile-token' : null;
  @override
  Future<bool> hasSession() async => active;
  void logout() {
    active = false;
    notifyListeners();
  }
}

Map<String, dynamic> profile(
  String id, {
  bool following = false,
  int followers = 7,
}) => {
  'id': id,
  'nickname': id == 'me' ? '내 이름' : '작성자 이름',
  'avatarUrl': null,
  'bio': '함께 달리는 러너',
  'followerCount': followers,
  'followingCount': 3,
  'isFollowing': following,
};
Map<String, dynamic> post(String id, String body, {String author = 'other'}) =>
    {
      'id': id,
      'body': body,
      'author': {'id': author, 'nickname': '작성자 이름', 'avatarUrl': null},
      'media': <dynamic>[],
    };
http.Response json(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
RunlineApi apiFor(
  Future<http.Response> Function(http.Request) handler, {
  ProfileSession? session,
}) => RunlineApi(
  baseUri: Uri.parse('https://api.example.com'),
  session: session ?? ProfileSession(),
  client: MockClient((request) async {
    expect(request.headers['Authorization'], 'Bearer profile-token');
    return handler(request);
  }),
);
Widget screen(RunlineApi api, {String? userId}) => MaterialApp(
  home: FeedProfileScreen(api: api, userId: userId),
);

void main() {
  testWidgets(
    'feed author opens real profile, follow refreshes counts and feed',
    (tester) async {
      var following = false;
      var feedCalls = 0;
      final api = apiFor((request) async {
        switch (request.url.path) {
          case '/api/v1/feed/recommended':
            feedCalls++;
            return json({
              'posts': following ? [] : [post('one', '러닝 소식')],
              'nextCursor': null,
            });
          case '/api/v1/me':
            return json({'profile': profile('me')});
          case '/api/v1/users/other':
            return json({
              'profile': profile(
                'other',
                following: following,
                followers: following ? 8 : 7,
              ),
            });
          case '/api/v1/users/other/follow':
            expect(request.method, following ? 'DELETE' : 'PUT');
            following = !following;
            return json({'isFollowing': following});
          default:
            fail('Unexpected request: ${request.url}');
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('작성자 이름'));
      await tester.pumpAndSettle();
      expect(find.text('함께 달리는 러너'), findsOneWidget);
      expect(find.text('팔로워 7'), findsOneWidget);
      expect(find.text('팔로잉 3'), findsOneWidget);
      await tester.tap(find.text('팔로우'));
      await tester.pumpAndSettle();
      expect(find.text('언팔로우'), findsOneWidget);
      expect(find.text('팔로워 8'), findsOneWidget);
      await tester.tap(find.text('언팔로우'));
      await tester.pumpAndSettle();
      expect(find.text('팔로워 7'), findsOneWidget);
      await tester.tap(find.text('팔로우'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(feedCalls, 2);
      expect(find.text('러닝 소식'), findsNothing);
    },
  );

  testWidgets(
    'own profile icon loads only own posts, pagination and stored detail',
    (tester) async {
      final api = apiFor((request) async {
        switch (request.url.path) {
          case '/api/v1/feed/recommended':
            return json({'posts': [], 'nextCursor': null});
          case '/api/v1/me':
            return json({'profile': profile('me')});
          case '/api/v1/me/posts':
            if (request.url.hasQuery) {
              expect(request.url.queryParameters['cursor'], 'page+/=');
              return json({
                'posts': [
                  post('one', '내 첫 글', author: 'me'),
                  post('two', '내 다음 글', author: 'me'),
                ],
                'nextCursor': null,
              });
            }
            return json({
              'posts': [post('one', '내 첫 글', author: 'me')],
              'nextCursor': 'page+/=',
            });
          case '/api/v1/feed/posts/one':
            return json({'post': post('one', '서버에 저장된 글 전문', author: 'me')});
          default:
            fail('Unexpected request: ${request.url}');
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeedScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('내 프로필'));
      await tester.pumpAndSettle();
      expect(find.text('내 이름'), findsOneWidget);
      expect(find.text('팔로우'), findsNothing);
      expect(find.text('내 첫 글'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('더 보기'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('내 첫 글'), findsOneWidget);
      expect(find.text('내 다음 글'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-post-one')),
      );
      await tester.tap(find.byKey(const ValueKey('profile-post-one')));
      await tester.pumpAndSettle();
      expect(find.text('서버에 저장된 글 전문'), findsOneWidget);
    },
  );

  testWidgets('opening own author ID never offers self-follow', (tester) async {
    final api = apiFor((request) async {
      if (request.url.path == '/api/v1/me')
        return json({'profile': profile('me')});
      expect(request.url.path, '/api/v1/me/posts');
      return json({'posts': [], 'nextCursor': null});
    });
    await tester.pumpWidget(screen(api, userId: 'me'));
    await tester.pumpAndSettle();
    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('팔로우'), findsNothing);
    expect(find.text('아직 작성한 게시물이 없어요.'), findsOneWidget);
  });

  testWidgets(
    'failed mutation retains state and prevents duplicate submission',
    (tester) async {
      final pending = Completer<http.Response>();
      var mutations = 0;
      final api = apiFor((request) async {
        if (request.method == 'PUT') {
          mutations++;
          return pending.future;
        }
        return json({
          'profile': profile(request.url.path.endsWith('/me') ? 'me' : 'other'),
        });
      });
      await tester.pumpWidget(screen(api, userId: 'other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로우'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(mutations, 1);
      pending.complete(
        json({
          'error': {'message': '잠시 후 다시 시도'},
        }, status: 503),
      );
      await tester.pumpAndSettle();
      expect(find.text('팔로우'), findsOneWidget);
      expect(find.text('팔로워 7'), findsOneWidget);
      expect(find.text('언팔로우'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('successful follow remains saved if profile refresh fails', (
    tester,
  ) async {
    var saved = false;
    final api = apiFor((request) async {
      if (request.method == 'PUT') {
        saved = true;
        return json({'isFollowing': true});
      }
      if (request.url.path == '/api/v1/me')
        return json({'profile': profile('me')});
      return saved
          ? json({
              'error': {'message': 'offline'},
            }, status: 500)
          : json({'profile': profile('other')});
    });
    await tester.pumpWidget(screen(api, userId: 'other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    expect(find.text('언팔로우'), findsOneWidget);
    expect(find.textContaining('팔로우 상태는 저장됐지만'), findsOneWidget);
  });

  testWidgets(
    'logout discards in-flight own posts and clears private profile',
    (tester) async {
      final session = ProfileSession();
      final pending = Completer<http.Response>();
      final api = apiFor((request) async {
        if (request.url.path == '/api/v1/me')
          return json({'profile': profile('me')});
        return pending.future;
      }, session: session);
      await tester.pumpWidget(screen(api));
      await tester.pump();
      await tester.pump();
      session.logout();
      await tester.pump();
      pending.complete(
        json({
          'posts': [post('one', '비공개 이전 소식')],
          'nextCursor': null,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('비공개 이전 소식'), findsNothing);
      expect(find.text('내 이름'), findsNothing);
      expect(find.textContaining('로그인 후 프로필'), findsOneWidget);
    },
  );

  testWidgets('profile fetch errors can be retried and narrow layout fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final api = apiFor((request) async {
      if (request.url.path == '/api/v1/me')
        return json({'profile': profile('me')});
      calls++;
      if (calls == 1)
        return json({
          'error': {'message': '사용자가 없습니다'},
        }, status: 404);
      return json({'profile': profile('other')});
    });
    await tester.pumpWidget(screen(api, userId: 'other'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('작성자 이름'), findsOneWidget);
    expect(find.text('이 사용자의 게시물 보기는 준비 중이에요.'), findsOneWidget);
    await tester.tap(find.byTooltip('루트'));
    await tester.pumpAndSettle();
    expect(find.text('프로필 루트 보기는 준비 중이에요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'session refresh during follow reloads the current profile after saving',
    (tester) async {
      final session = ProfileSession();
      final pending = Completer<http.Response>();
      var following = false;
      var changed = 0;
      final api = apiFor((request) async {
        if (request.method == 'PUT') return pending.future;
        if (request.url.path == '/api/v1/me')
          return json({'profile': profile('me')});
        return json({
          'profile': profile(
            'other',
            following: following,
            followers: following ? 8 : 7,
          ),
        });
      }, session: session);
      await tester.pumpWidget(
        MaterialApp(
          home: FeedProfileScreen(
            api: api,
            userId: 'other',
            onFollowChanged: () => changed++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로우'));
      await tester.pump();
      session.notifyListeners();
      await tester.pumpAndSettle();
      following = true;
      pending.complete(json({'isFollowing': true}));
      await tester.pumpAndSettle();
      expect(find.text('언팔로우'), findsOneWidget);
      expect(find.text('팔로워 8'), findsOneWidget);
      expect(changed, 1);
    },
  );

  testWidgets(
    'own photo grid uses signed authenticated media and opens its stored post',
    (tester) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uw0AAAAASUVORK5CYII=',
      );
      var images = 0;
      final photo = post('photo', '사진 게시물', author: 'me');
      photo['media'] = [
        {
          'id': 'image',
          'url': 'https://api.example.com/api/v1/feed/media/image?signature=signed',
        },
      ];
      final api = apiFor((request) async {
        switch (request.url.path) {
          case '/api/v1/me':
            return json({'profile': profile('me')});
          case '/api/v1/me/posts':
            return json({
              'posts': [photo],
              'nextCursor': null,
            });
          case '/api/v1/feed/posts/photo':
            return json({'post': photo});
          case '/api/v1/feed/media/image':
            images++;
            expect(request.url.queryParameters['signature'], 'signed');
            return http.Response.bytes(
              png,
              200,
              headers: {'content-type': 'image/png'},
            );
          default:
            fail('Unexpected request: ${request.url}');
        }
      });
      await tester.pumpWidget(screen(api));
      await tester.pumpAndSettle();
      expect(images, 1);
      await tester.tap(find.byKey(const ValueKey('profile-post-photo')));
      await tester.pumpAndSettle();
      expect(find.text('사진 게시물'), findsOneWidget);
      expect(images, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'own posts page retry preserves cursor and previously loaded posts',
    (tester) async {
      var pages = 0;
      final api = apiFor((request) async {
        if (request.url.path == '/api/v1/me')
          return json({'profile': profile('me')});
        expect(request.url.path, '/api/v1/me/posts');
        pages++;
        if (pages == 1)
          return json({
            'posts': [post('one', '보존할 글')],
            'nextCursor': 'page-two',
          });
        expect(request.url.queryParameters['cursor'], 'page-two');
        if (pages == 2)
          return json({
            'error': {'message': '목록 오류'},
          }, status: 500);
        return json({
          'posts': [post('two', '추가된 글')],
          'nextCursor': null,
        });
      });
      await tester.pumpWidget(screen(api));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('더 보기'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('보존할 글'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('다시 시도'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('보존할 글'), findsOneWidget);
      expect(find.text('추가된 글'), findsOneWidget);
    },
  );
}
