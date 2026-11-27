import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/feed/feed_follow_list_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

import 'support/test_runline_auth.dart';

http.Response response(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> user(String id, String name) => {
  'id': id,
  'nickname': name,
  'avatarUrl': null,
  'isFollowing': true,
};

RunlineApi apiFor(
  Future<http.Response> Function(http.Request) handler, {
  TestRunlineAuth? session,
}) => RunlineApi(
  baseUri: Uri.parse('https://api.example.com'),
  session: session ?? (TestRunlineAuth()..setAccessToken('test-token')),
  client: MockClient(handler),
);

Widget screen(
  RunlineApi api, {
  bool following = true,
  bool ownProfile = true,
  String userId = 'test-user',
  VoidCallback? onFollowChanged,
}) => MaterialApp(
  home: FeedFollowListScreen(
    userId: userId,
    following: following,
    ownProfile: ownProfile,
    api: api,
    onFollowChanged: onFollowChanged,
  ),
);

void main() {
  testWidgets(
    'failed unfollow keeps the row and supports retry without duplicates',
    (tester) async {
      final pending = Completer<http.Response>();
      var deletes = 0;
      var changed = 0;
      final api = apiFor((request) async {
        if (request.method == 'DELETE') {
          deletes++;
          expect(request.url.path, '/api/v1/users/other/follow');
          return deletes == 1
              ? pending.future
              : response({'isFollowing': false});
        }
        return response({
          'users': [user('other', '함께 달리는 러너')],
          'nextCursor': null,
        });
      });
      await tester.pumpWidget(screen(api, onFollowChanged: () => changed++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로우 취소'));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(deletes, 1);
      pending.complete(
        response({
          'error': {'message': '연결 오류'},
        }, status: 500),
      );
      await tester.pumpAndSettle();
      expect(find.text('함께 달리는 러너'), findsOneWidget);
      expect(find.text('연결 오류'), findsOneWidget);
      expect(changed, 0);
      await tester.tap(find.text('팔로우 취소'));
      await tester.pumpAndSettle();
      expect(find.text('함께 달리는 러너'), findsNothing);
      expect(changed, 1);
      expect(deletes, 2);
    },
  );

  testWidgets(
    'pagination encodes cursor, retries the same page and deduplicates',
    (tester) async {
      var pages = 0;
      final api = apiFor((request) async {
        pages++;
        expect(request.url.path, '/api/v1/users/test-user/followers');
        if (pages == 1) {
          expect(request.url.hasQuery, false);
          return response({
            'users': [user('one', '첫 번째 러너')],
            'nextCursor': 'page+/=',
          });
        }
        expect(request.url.queryParameters['cursor'], 'page+/=');
        if (pages == 2) {
          return response({
            'error': {'message': '목록 오류'},
          }, status: 500);
        }
        return response({
          'users': [user('one', '첫 번째 러너'), user('two', '두 번째 러너')],
          'nextCursor': null,
        });
      });
      await tester.pumpWidget(screen(api, following: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('첫 번째 러너'), findsOneWidget);
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('첫 번째 러너'), findsOneWidget);
      expect(find.text('두 번째 러너'), findsOneWidget);
      expect(find.text('팔로우 취소'), findsNothing);
      expect(pages, 3);
    },
  );

  testWidgets(
    'another profile following list cannot remove its relationships',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = apiFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/users/other/following');
        return response({
          'users': [user('runner', '아주 긴 이름을 가진 다른 러너입니다')],
          'nextCursor': null,
        });
      });
      await tester.pumpWidget(screen(api, userId: 'other', ownProfile: false));
      await tester.pumpAndSettle();
      expect(find.text('팔로우 취소'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('row opens that runner profile', (tester) async {
    final api = apiFor((request) async {
      switch (request.url.path) {
        case '/api/v1/users/test-user/following':
          return response({
            'users': [user('other', '목록의 러너')],
            'nextCursor': null,
          });
        case '/api/v1/me':
          return response({'profile': user('test-user', '나')});
        case '/api/v1/users/other':
          return response({
            'profile': {
              ...user('other', '선택한 러너의 프로필'),
              'followerCount': 1,
              'followingCount': 2,
            },
          });
        default:
          fail('Unexpected request: ${request.url}');
      }
    });
    await tester.pumpWidget(screen(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목록의 러너'));
    await tester.pumpAndSettle();
    expect(find.text('선택한 러너의 프로필'), findsOneWidget);
    expect(find.text('팔로워 1'), findsOneWidget);
    expect(find.text('팔로잉 2'), findsOneWidget);
  });

  testWidgets('logout discards in-flight list and clears loaded users', (
    tester,
  ) async {
    final session = TestRunlineAuth()..setAccessToken('test-token');
    final pending = Completer<http.Response>();
    final api = apiFor((request) async => pending.future, session: session);
    await tester.pumpWidget(screen(api));
    await tester.pump();
    session.setAccessToken(null);
    await tester.pump();
    pending.complete(
      response({
        'users': [user('other', '이전 계정의 목록')],
        'nextCursor': null,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('이전 계정의 목록'), findsNothing);
    expect(find.text('로그인 후 목록을 확인해주세요.'), findsOneWidget);
    expect(find.text('팔로우 취소'), findsNothing);
  });

  testWidgets('session refresh during unfollow reloads saved list', (
    tester,
  ) async {
    final session = TestRunlineAuth()..setAccessToken('test-token');
    final pending = Completer<http.Response>();
    var following = true;
    var changed = 0;
    final api = apiFor((request) async {
      if (request.method == 'DELETE') return pending.future;
      return response({
        'users': following ? [user('other', '팔로잉 러너')] : [],
        'nextCursor': null,
      });
    }, session: session);
    await tester.pumpWidget(screen(api, onFollowChanged: () => changed++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팔로우 취소'));
    await tester.pump();
    session.setAccessToken('refreshed-token');
    await tester.pumpAndSettle();
    following = false;
    pending.complete(response({'isFollowing': false}));
    await tester.pumpAndSettle();
    expect(find.text('팔로잉 러너'), findsNothing);
    expect(find.text('아직 팔로잉한 러너가 없어요.'), findsOneWidget);
    expect(changed, 1);
  });
}
