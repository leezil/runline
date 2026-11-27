import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/shared/media/image_compose_screen.dart';
import 'package:runline/shared/media/image_optimizer.dart';
import 'package:runline/shared/media/image_picker_field.dart';
import 'package:runline/shared/media/runline_api.dart';

class EditorSession extends RunlineAuth {
  String? account = 'owner';
  @override
  String? get userId => account;
  @override
  String? get accessToken => account == null ? null : 'token-$account';
  @override
  bool get isSignedIn => account != null;
  @override
  Future<bool> hasSession() async => isSignedIn;
  void changeAccount(String? value) {
    account = value;
    notifyListeners();
  }
}

http.Response json(Object value, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json'},
);

class EditorServer {
  final session = EditorSession();
  final photo = img.encodePng(img.Image(width: 2, height: 2));
  final patches = <Map<String, dynamic>>[];
  int uploads = 0;
  bool failSave = false;
  Completer<http.Response>? pendingUpload;
  Map<String, dynamic> post({String body = '기존 게시글', int photos = 2}) => {
    'id': 'post-id',
    'body': body,
    'author': {'id': 'owner', 'nickname': '작성자', 'avatarUrl': null},
    'media': [
      for (var index = 0; index < photos; index++)
        {
          'id': 'old-$index',
          'url': '/api/v1/feed/media/old-$index?signature=signed',
        },
    ],
  };
  OptimizedUploadImage newPhoto() => OptimizedUploadImage(
    bytes: photo,
    contentType: 'image/png',
    filename: 'new.png',
    width: 2,
    height: 2,
  );
  late final api = RunlineApi(
    session: session,
    baseUri: Uri.parse('https://api.example.com'),
    client: MockClient((request) async {
      if (request.url.path.startsWith('/api/v1/feed/media/')) {
        return http.Response.bytes(
          photo,
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      if (request.url.path == '/api/v1/feed/media') {
        uploads++;
        if (pendingUpload != null) return pendingUpload!.future;
        return json({
          'media': {'id': 'new-$uploads'},
        }, status: 201);
      }
      if (request.url.path == '/api/v1/feed/posts/post-id' &&
          request.method == 'PATCH') {
        patches.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (failSave) {
          return json({
            'error': {'message': '수정을 저장하지 못했어요.'},
          }, status: 500);
        }
        return json({'post': post()});
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }),
  );
}

Future<void> launchEditor(
  WidgetTester tester,
  EditorServer server, {
  Map<String, dynamic>? post,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ImageComposeScreen(
                  kind: ImageComposeKind.feed,
                  api: server.api,
                  post: post ?? server.post(),
                ),
              ),
            ),
            child: const Text('편집 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('편집 열기'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('저장'));
  await tester.tap(find.text('저장'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editor prefills content and keeps existing photos in a PATCH', (
    tester,
  ) async {
    final server = EditorServer();
    await launchEditor(tester, server);
    expect(find.text('게시글 수정'), findsOneWidget);
    expect(find.text('기존 게시글'), findsOneWidget);
    expect(find.byKey(const ValueKey('existing-media-old-0')), findsOneWidget);
    expect(
      tester
          .widget<UploadImagePicker>(find.byType(UploadImagePicker))
          .maxImages,
      2,
    );
    await tester.enterText(find.byType(TextField), '  수정한 게시글  ');
    await save(tester);
    expect(server.patches.single, {
      'body': '수정한 게시글',
      'mediaIds': ['old-0', 'old-1'],
    });
    expect(server.uploads, 0);
    expect(find.byType(ImageComposeScreen), findsNothing);
  });

  testWidgets('editor removes old photos and attaches newly uploaded photos', (
    tester,
  ) async {
    final server = EditorServer();
    await launchEditor(tester, server);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('existing-media-old-0')),
        matching: find.byTooltip('첨부 사진 삭제'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('existing-media-old-0')), findsNothing);
    final picker = tester.widget<UploadImagePicker>(
      find.byType(UploadImagePicker),
    );
    expect(picker.maxImages, 3);
    picker.onChanged([server.newPhoto()]);
    await tester.pumpAndSettle();
    await save(tester);
    expect(server.uploads, 1);
    expect(server.patches.single['mediaIds'], ['old-1', 'new-1']);
  });

  testWidgets('failed save retains the draft and uploaded IDs for retry', (
    tester,
  ) async {
    final server = EditorServer()..failSave = true;
    await launchEditor(tester, server, post: server.post(photos: 0));
    await tester.enterText(find.byType(TextField), '재시도할 내용');
    tester.widget<UploadImagePicker>(find.byType(UploadImagePicker)).onChanged([
      server.newPhoto(),
    ]);
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text('수정을 저장하지 못했어요.'), findsOneWidget);
    expect(find.text('재시도할 내용'), findsOneWidget);
    expect(server.uploads, 1);
    server.failSave = false;
    await save(tester);
    expect(server.uploads, 1);
    expect(server.patches, [
      {
        'body': '재시도할 내용',
        'mediaIds': ['new-1'],
      },
      {
        'body': '재시도할 내용',
        'mediaIds': ['new-1'],
      },
    ]);
    expect(find.byType(ImageComposeScreen), findsNothing);
  });

  testWidgets('cannot save an empty post after removing its last photo', (
    tester,
  ) async {
    final server = EditorServer();
    await launchEditor(tester, server, post: server.post(body: '', photos: 1));
    await tester.tap(find.byTooltip('첨부 사진 삭제'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text('내용(최대 2,000자) 또는 사진을 추가해주세요.'), findsOneWidget);
    expect(server.patches, isEmpty);
    await tester.enterText(find.byType(TextField), '사진 없는 게시글');
    await save(tester);
    expect(server.patches.single, {'body': '사진 없는 게시글', 'mediaIds': []});
  });

  testWidgets(
    'same-account refresh preserves draft but account switch clears it',
    (tester) async {
      final server = EditorServer();
      await launchEditor(tester, server);
      await tester.enterText(find.byType(TextField), '비공개 작성 중');
      server.session.changeAccount('owner');
      await tester.pumpAndSettle();
      expect(find.text('비공개 작성 중'), findsOneWidget);
      server.session.changeAccount('another');
      await tester.pumpAndSettle();
      expect(find.text('비공개 작성 중'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('계정이 변경되었어요. 돌아간 뒤 다시 시도해주세요.'), findsOneWidget);
      expect(server.patches, isEmpty);
    },
  );

  testWidgets('logout during upload prevents the subsequent PATCH', (
    tester,
  ) async {
    final server = EditorServer()..pendingUpload = Completer<http.Response>();
    await launchEditor(tester, server, post: server.post(photos: 0));
    tester.widget<UploadImagePicker>(find.byType(UploadImagePicker)).onChanged([
      server.newPhoto(),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    server.session.changeAccount(null);
    await tester.pump();
    server.pendingUpload!.complete(
      json({
        'media': {'id': 'uploaded'},
      }, status: 201),
    );
    await tester.pumpAndSettle();
    expect(server.uploads, 1);
    expect(server.patches, isEmpty);
    expect(find.byType(ImageComposeScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
