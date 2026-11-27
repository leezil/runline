import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:runline/features/club/club_settings_screen.dart';
import 'package:runline/features/feed/widgets/feed_avatar.dart';
import 'package:runline/features/settings/settings_screen.dart';
import 'package:runline/shared/media/image_optimizer.dart';
import 'package:runline/shared/media/image_picker_field.dart';
import 'package:runline/shared/media/runline_api.dart';

import 'support/test_runline_auth.dart';

http.Response json(Object data, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

class ProfileServer {
  final session = TestRunlineAuth()..setAccessToken('token');
  final photo = img.encodePng(img.Image(width: 2, height: 2));
  String name = '기존 러너';
  String? avatar;
  bool failSave = false;
  int saves = 0, uploads = 0;

  late final api = RunlineApi(
    session: session,
    baseUri: Uri.parse('https://api.example.com'),
    client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      switch (request.url.path) {
        case '/api/v1/me':
          return json({
            'profile': {
              'id': 'test-user',
              'nickname': name,
              'avatarUrl': avatar,
            },
          });
        case '/api/v1/me/profile':
          if (request.method == 'PATCH') {
            saves++;
            if (failSave) {
              return json({
                'error': {'message': '저장을 다시 시도해주세요.'},
              }, status: 500);
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            name = body['nickname'] as String? ?? name;
            if (body.containsKey('avatarUrl')) avatar = null;
          }
          return json({
            'profile': {
              'id': 'test-user',
              'nickname': name,
              'avatar_url': avatar,
            },
          });
        case '/api/v1/me/avatar':
          expect(request.method, 'POST');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data;'),
          );
          uploads++;
          avatar = '/api/v1/media/images/new-avatar';
          return json({
            'ok': true,
            'image': {'url': avatar},
          }, status: 201);
        case '/api/v1/media/images/new-avatar':
          return http.Response.bytes(
            photo,
            200,
            headers: {'content-type': 'image/png'},
          );
        default:
          fail('Unexpected request: ${request.method} ${request.url}');
      }
    }),
  );
}

Future<void> launch(WidgetTester tester, RunlineApi api) async {
  await tester.pumpWidget(MaterialApp(home: SettingsScreen(api: api)));
  await tester.pumpAndSettle();
}

Future<void> edit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('프로필 편집'));
  await tester.tap(find.text('프로필 편집'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings edits the actual shared name and rejects a blank name',
    (tester) async {
      final server = ProfileServer();
      await launch(tester, server.api);
      expect(find.text('기존 러너'), findsOneWidget);
      expect(find.text('민지 러너'), findsNothing);
      expect(find.text('runline@runner.com'), findsNothing);
      await edit(tester);
      expect(find.byType(ClubProfileEditorScreen), findsOneWidget);
      final name = find.widgetWithText(TextFormField, '닉네임');
      await tester.enterText(name, '   ');
      await tester.tap(find.text('프로필 저장'));
      await tester.pumpAndSettle();
      expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
      expect(server.saves, 0);
      await tester.enterText(name, '  새 러너  ');
      await tester.tap(find.text('프로필 저장'));
      await tester.pumpAndSettle();
      expect(server.name, '새 러너');
      expect(server.saves, 1);
      expect(find.byType(ClubProfileEditorScreen), findsNothing);
      expect(find.text('새 러너'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('photo upload preserves the name draft and refreshes settings', (
    tester,
  ) async {
    final server = ProfileServer();
    await launch(tester, server.api);
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '닉네임'), '사진과 이름');
    await tester.tap(find.text('프로필 사진 변경'));
    await tester.pumpAndSettle();
    tester.widget<UploadImagePicker>(find.byType(UploadImagePicker)).onChanged([
      OptimizedUploadImage(
        bytes: server.photo,
        contentType: 'image/png',
        filename: 'profile.png',
        width: 2,
        height: 2,
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(server.uploads, 1);
    expect(find.text('사진과 이름'), findsOneWidget);
    expect(
      tester.widget<FeedAvatar>(find.byType(FeedAvatar).last).avatarUrl,
      server.avatar,
    );
    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();
    expect(find.text('사진과 이름'), findsOneWidget);
    expect(
      tester.widget<FeedAvatar>(find.byType(FeedAvatar)).avatarUrl,
      server.avatar,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save retains the entered name and can be retried', (
    tester,
  ) async {
    final server = ProfileServer()..failSave = true;
    await launch(tester, server.api);
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '닉네임'), '다시 달리기');
    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();
    expect(find.byType(ClubProfileEditorScreen), findsOneWidget);
    expect(find.text('다시 달리기'), findsOneWidget);
    expect(server.name, '기존 러너');
    expect(find.text('저장을 다시 시도해주세요.'), findsOneWidget);
    server.failSave = false;
    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();
    expect(server.name, '다시 달리기');
    expect(find.byType(ClubProfileEditorScreen), findsNothing);
  });

  testWidgets('logout discards a late profile response', (tester) async {
    final session = TestRunlineAuth()..setAccessToken('token');
    final pending = Completer<http.Response>();
    final api = RunlineApi(
      session: session,
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient((_) => pending.future),
    );
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(api: api)));
    await tester.pump();
    session.setAccessToken(null);
    pending.complete(
      json({
        'profile': {'nickname': '이전 계정', 'avatarUrl': null},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('이전 계정'), findsNothing);
    expect(find.text('로그인 후 프로필을 편집해주세요.'), findsOneWidget);
  });

  testWidgets(
    'signed-out profile editing prompts for login without a request',
    (tester) async {
      var requests = 0;
      final api = RunlineApi(
        session: TestRunlineAuth(),
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) async {
          requests++;
          return json({});
        }),
      );
      await launch(tester, api);
      await edit(tester);
      expect(find.byType(ClubProfileEditorScreen), findsNothing);
      expect(requests, 0);
      expect(find.text('로그인 후 프로필을 편집해주세요.'), findsNWidgets(2));
    },
  );
}
