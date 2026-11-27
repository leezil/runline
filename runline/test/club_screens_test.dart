import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runline/features/auth/runline_auth.dart';
import 'package:runline/features/club/club_ui.dart';
import 'package:runline/features/club/club_files.dart';
import 'package:runline/features/club/club_screen.dart';
import 'package:runline/features/club/club_members_screen.dart';
import 'package:runline/features/club/club_running_screen.dart';
import 'package:runline/features/club/club_run_detail_screen.dart';
import 'package:runline/features/club/club_run_editor_screen.dart';
import 'package:runline/features/club/club_notices_screen.dart';
import 'package:runline/features/club/club_notice_editor_screen.dart';
import 'package:runline/features/club/club_settings_screen.dart';
import 'package:runline/shared/media/runline_api.dart';
import 'package:runline/shared/media/image_optimizer.dart';
import 'package:runline/shared/media/image_picker_field.dart';

const clubId = '11111111-1111-4111-8111-111111111111';
const noticeId = '22222222-2222-4222-8222-222222222222';
const runId = '33333333-3333-4333-8333-333333333333';
const mine = '44444444-4444-4444-8444-444444444444';
const another = '55555555-5555-4555-8555-555555555555';

class UiAuth extends RunlineAuth {
  String? account = 'user';
  void switchAccount(String account) {
    this.account = account;
    notifyListeners();
  }

  @override
  bool get isSignedIn => account != null;
  @override
  String? get userId => account;
  @override
  String? get accessToken => account == null ? null : 'token-$account';
  @override
  Future<bool> hasSession() async => isSignedIn;
  void logout() {
    account = null;
    notifyListeners();
  }
}

http.Response response(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

class ClubServer {
  bool joined = true,
      owner = true,
      participating = false,
      deletedNotice = false;
  bool failChat = false, rejectJoin = false, kicked = false;
  final calls = <http.Request>[];
  final club = <String, dynamic>{
    'id': clubId,
    'name': '한강 러너스',
    'region': '서울',
    'description': '함께 달려요',
    'member_count': 2,
    'image_url': null,
  };
  final notice = <String, dynamic>{
    'id': noticeId,
    'title': '주말 모임 안내',
    'content': '함께 러닝해요.',
    'pinned': false,
    'author_nickname': '클럽장',
    'created_at': '2026-11-27T01:00:00Z',
    'attachments': <Map<String, dynamic>>[],
  };
  late final run = <String, dynamic>{
    'id': runId,
    'title': '주말 한강 러닝',
    'description': '천천히 달려요.',
    'location': '한강공원',
    'starts_at': DateTime.now()
        .add(const Duration(days: 2))
        .toUtc()
        .toIso8601String(),
    'ends_at': DateTime.now()
        .add(const Duration(days: 2, hours: 1))
        .toUtc()
        .toIso8601String(),
    'registration_closes_at': DateTime.now()
        .add(const Duration(days: 1))
        .toUtc()
        .toIso8601String(),
    'capacity': 10,
    'participant_count': 1,
    'creator_membership_id': another,
    'creator_nickname': '생성자',
    'creator_avatar_url': null,
    'state': 'recruiting',
    'is_participating': false,
  };
  ClubMap get membership => {'id': mine, 'role': owner ? 'owner' : 'member'};
  List<ClubMap> get members => [
    {
      'id': mine,
      'user_id': 'user',
      'nickname': '클럽장',
      'avatar_url': null,
      'role': 'owner',
    },
    if (!kicked)
      {
        'id': another,
        'user_id': 'other',
        'nickname': '민수',
        'avatar_url': null,
        'role': 'member',
      },
  ];
  ClubMap page(List items, [String? cursor]) => {
    'ok': true,
    'items': items,
    'nextCursor': cursor,
  };
  Future<http.Response> handle(http.Request request) async {
    calls.add(request);
    expect(request.headers['Authorization'], 'Bearer token-user');
    expect(request.followRedirects, isFalse);
    final path = request.url.path.replaceFirst('/api/v1', '');
    final method = request.method;
    final body =
        request.headers['content-type']?.startsWith('application/json') == true
        ? jsonDecode(request.body) as ClubMap
        : <String, dynamic>{};
    if (path == '/me/club') {
      return response({
        'club': joined ? club : null,
        'membership': joined ? membership : null,
      });
    }
    if (path == '/me/profile') {
      return response({
        'profile': {
          'id': 'user',
          'nickname': body['nickname'] ?? '러너',
          'avatar_url': null,
        },
      });
    }
    if (path == '/clubs' || path == '/clubs/recommended') {
      if (method == 'POST') {
        joined = true;
        return response({'club': club, 'membership': membership}, 201);
      }
      return response(page([club]));
    }
    if (path == '/clubs/$clubId/home') {
      return response({'club': club, 'membership': membership});
    }
    if (path == '/clubs/$clubId/chat') {
      return failChat
          ? response({
              'error': {'message': 'unavailable'},
            }, 503)
          : response({
              'state': {'unread_count': 2},
            });
    }
    if (path == '/clubs/$clubId/join') {
      joined = true;
      return response({'club': club, 'membership': membership}, 201);
    }
    if (path == '/clubs/$clubId/leave' ||
        (path == '/clubs/$clubId' && method == 'DELETE')) {
      joined = false;
      return http.Response('', 204);
    }
    if (path == '/clubs/$clubId') {
      if (method == 'PATCH') club.addAll(body);
      return response({'club': club});
    }
    if (path == '/clubs/$clubId/ownership') {
      owner = false;
      return http.Response('', 204);
    }
    if (path.startsWith('/clubs/$clubId/members/')) {
      kicked = true;
      return http.Response('', 204);
    }
    if (path == '/clubs/$clubId/members') {
      final query = request.url.queryParameters['query'] ?? '';
      return response(
        page(
          members
              .where((m) => (m['nickname'] as String).contains(query))
              .toList(),
        ),
      );
    }
    if (path == '/clubs/$clubId/feed') {
      return response(
        page([
          {
            'id': 'event',
            'target_type': 'run',
            'target_id': runId,
            'title': '주말 한강 러닝',
            'type': 'run_created',
            'created_at': '2026-11-27T01:00:00Z',
          },
        ]),
      );
    }
    if (path == '/clubs/$clubId/notices') {
      if (method == 'POST') {
        notice.addAll(body);
        return response({'notice': notice}, 201);
      }
      return response(
        page(
          deletedNotice
              ? []
              : [
                  {
                    ...notice,
                    'attachment_count': (notice['attachments'] as List).length,
                  },
                ],
        ),
      );
    }
    if (path == '/clubs/$clubId/notices/$noticeId') {
      if (method == 'DELETE') {
        deletedNotice = true;
        return http.Response('', 204);
      }
      if (method == 'PATCH') notice.addAll(body);
      return response({'notice': notice});
    }
    if (path == '/clubs/$clubId/notices/$noticeId/attachments' &&
        method == 'POST') {
      (notice['attachments'] as List).add({
        'id': 'file',
        'filename': '안내.pdf',
        'content_type': 'application/pdf',
        'size': 3,
        'image_url': null,
      });
      return response({
        'attachment': (notice['attachments'] as List).last,
      }, 201);
    }
    if (path.endsWith('/attachments/file')) {
      if (method == 'DELETE') {
        (notice['attachments'] as List).clear();
        return http.Response('', 204);
      }
      return http.Response.bytes([1, 2, 3], 200);
    }
    if (path == '/clubs/$clubId/runs') {
      if (method == 'POST') {
        run['title'] = body['title'];
        return response({'run': run}, 201);
      }
      return response(
        page([
          {...run, 'is_participating': participating},
        ]),
      );
    }
    if (path == '/clubs/$clubId/runs/$runId/cancel') {
      run['state'] = 'cancelled';
      return http.Response('', 204);
    }
    if (path == '/clubs/$clubId/runs/$runId/participants' && method == 'POST') {
      if (rejectJoin) {
        return response({
          'error': {'code': 'RUN_NOT_RECRUITING', 'message': 'full'},
        }, 409);
      }
      participating = true;
      return response({'run': run}, 201);
    }
    if (path.endsWith('/participants/me')) {
      participating = false;
      return http.Response('', 204);
    }
    if (path == '/clubs/$clubId/runs/$runId/participants') {
      return response(page(members));
    }
    if (path == '/clubs/$clubId/runs/$runId') {
      if (method == 'PATCH') run.addAll(body);
      return response({
        'run': {
          ...run,
          'is_participating': participating,
          'participant_count': participating ? 2 : 1,
        },
      });
    }
    return response({
      'error': {'message': 'unexpected $method $path'},
    }, 404);
  }

  RunlineApi api([UiAuth? session]) => RunlineApi(
    session: session ?? UiAuth(),
    baseUri: Uri.parse('https://api.example.com'),
    client: MockClient(handle),
  );
}

class PendingAuth extends UiAuth {
  final pending = Completer<bool>();
  @override
  Future<bool> hasSession() => pending.future;
}

class MemoryClubFiles extends ClubFiles {
  Uint8List? saved;
  String? savedName;
  @override
  Future<ClubAttachmentFile?> pick() async => ClubAttachmentFile(
    '안내.pdf',
    'application/pdf',
    Uint8List.fromList([1, 2, 3]),
  );
  @override
  Future<Uri?> save(String name, String contentType, Uint8List bytes) async {
    saved = bytes;
    savedName = name;
    return Uri.parse('file:///test.pdf');
  }
}

Future<void> launch(WidgetTester tester, RunlineApi api, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => openClubPage(context, api, screen),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('joins from recommendations and switches to the club home', (
    tester,
  ) async {
    final server = ClubServer()..joined = false;
    final api = server.api();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClubScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('클럽 검색'), findsOneWidget);
    expect(find.byTooltip('클럽 만들기'), findsOneWidget);
    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('클럽 검색'), findsNothing);
    expect(find.byTooltip('클럽 만들기'), findsNothing);
    expect(find.text('공지'), findsOneWidget);
    expect(find.text('멤버'), findsOneWidget);
    expect(find.text('클럽 러닝'), findsOneWidget);
    expect(find.text('채팅'), findsOneWidget);
    await tester.tap(find.text('주말 한강 러닝'));
    await tester.pumpAndSettle();
    expect(find.text('클럽 러닝 상세'), findsOneWidget);
    expect(
      server.calls.any(
        (c) => c.url.path.endsWith('/join') && c.method == 'POST',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat badge failure does not block the club feed', (
    tester,
  ) async {
    final server = ClubServer()..failChat = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClubScreen(api: server.api())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('주말 한강 러닝'), findsOneWidget);
    expect(find.textContaining('미확인 수를'), findsOneWidget);
  });

  testWidgets('searches members and confirms ownership transfer', (
    tester,
  ) async {
    final server = ClubServer();
    final client = server.api();
    await launch(
      tester,
      client,
      ClubMembersScreen(
        clubId: clubId,
        membership: server.membership,
        api: client,
      ),
    );
    await tester.enterText(find.byType(TextField), '민수');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('클럽장'), findsNothing);
    expect(server.calls.last.url.queryParameters['query'], '민수');
    await tester.tap(find.byTooltip('멤버 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('클럽장 위임'));
    await tester.pumpAndSettle();
    expect(server.owner, isTrue);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    final sent = server.calls.singleWhere(
      (c) => c.url.path.endsWith('/ownership'),
    );
    expect(jsonDecode(sent.body), {'membershipId': another});
    expect(server.owner, isFalse);
  });

  testWidgets(
    'members can join and withdraw, while a full run shows a retryable error',
    (tester) async {
      final server = ClubServer()..owner = false;
      final api = server.api();
      await launch(
        tester,
        api,
        ClubRunDetailScreen(clubId: clubId, runId: runId, api: api),
      );
      expect(find.byTooltip('러닝 수정'), findsNothing);
      await tester.tap(find.text('참가하기'));
      await tester.pumpAndSettle();
      expect(server.participating, isTrue);
      await tester.tap(find.text('참가 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.participating, isFalse);
      server.rejectJoin = true;
      await tester.tap(find.text('참가하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('정원이 찬'), findsOneWidget);
      expect(find.text('참가하기'), findsOneWidget);
    },
  );

  testWidgets('creating a run submits actual form values with UTC schedule', (
    tester,
  ) async {
    final server = ClubServer();
    final client = server.api();
    await launch(
      tester,
      client,
      ClubRunEditorScreen(clubId: clubId, api: client),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '러닝 제목'),
      '저녁 5km',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '모임 장소'),
      '서울숲 정문',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('저장'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final sent = server.calls.singleWhere(
      (c) => c.method == 'POST' && c.url.path.endsWith('/runs'),
    );
    final body = jsonDecode(sent.body) as ClubMap;
    expect(body['title'], '저녁 5km');
    expect(body['location'], '서울숲 정문');
    expect(body['capacity'], 10);
    expect(DateTime.parse(body['startsAt'] as String).isUtc, isTrue);
    expect(
      DateTime.parse(body['endsAt'] as String)
          .isAfter(DateTime.parse(body['startsAt'] as String)),
      isTrue,
    );
  });

  testWidgets(
    'editing a closed run keeps unchanged past registration times out of PATCH',
    (tester) async {
      final server = ClubServer();
      server.run['state'] = 'closed';
      server.run['registration_closes_at'] = DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String();
      final api = server.api();
      await launch(
        tester,
        api,
        ClubRunEditorScreen(clubId: clubId, run: server.run, api: api),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '러닝 제목'),
        '장소 확인 러닝',
      );
      tester.testTextInput.hide();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('저장'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final sent = server.calls.singleWhere((c) => c.method == 'PATCH');
      expect(jsonDecode(sent.body), {'title': '장소 확인 러닝'});
    },
  );

  testWidgets('run list switches between recruiting and past API filters', (
    tester,
  ) async {
    final server = ClubServer();
    final client = server.api();
    await launch(
      tester,
      client,
      ClubRunningScreen(clubId: clubId, api: client),
    );
    await tester.tap(find.text('지난 러닝'));
    await tester.pumpAndSettle();
    expect(server.calls.last.url.queryParameters['filter'], 'past');
  });

  testWidgets('notice owner can pin and delete with confirmation', (
    tester,
  ) async {
    final server = ClubServer();
    final client = server.api();
    await launch(
      tester,
      client,
      ClubNoticeDetailScreen(clubId: clubId, noticeId: noticeId, api: client),
    );
    await tester.tap(find.byTooltip('공지 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상단 고정'));
    await tester.pumpAndSettle();
    expect(server.notice['pinned'], isTrue);
    await tester.tap(find.byTooltip('공지 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공지 삭제'));
    await tester.pumpAndSettle();
    expect(server.deletedNotice, isFalse);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(server.deletedNotice, isTrue);
  });

  testWidgets('notice editor saves title, body and pin to the existing API', (
    tester,
  ) async {
    final server = ClubServer();
    final client = server.api();
    await launch(
      tester,
      client,
      ClubNoticeEditorScreen(clubId: clubId, api: client),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '공지 제목'),
      '정기 모임',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '공지 내용'),
      '토요일 9시 집합',
    );
    await tester.tap(find.byType(Switch));
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('저장'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final sent = server.calls.singleWhere((c) => c.method == 'POST');
    expect(jsonDecode(sent.body), {
      'title': '정기 모임',
      'content': '토요일 9시 집합',
      'pinned': true,
    });
  });

  testWidgets(
    'document attachments upload, save with auth headers, and delete',
    (tester) async {
      final server = ClubServer();
      final api = server.api(), files = MemoryClubFiles();
      await launch(
        tester,
        api,
        ClubNoticeDetailScreen(
          clubId: clubId,
          noticeId: noticeId,
          api: api,
          files: files,
        ),
      );
      await tester.tap(find.byTooltip('공지 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('문서 첨부'));
      await tester.pumpAndSettle();
      final upload = server.calls.singleWhere((c) => c.method == 'POST');
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(upload.bodyBytes, containsAllInOrder([1, 2, 3]));
      await tester.tap(find.byTooltip('첨부파일 저장'));
      await tester.pumpAndSettle();
      expect(files.saved, [1, 2, 3]);
      expect(files.savedName, '안내.pdf');
      final download = server.calls.singleWhere(
        (c) => c.method == 'GET' && c.url.path.endsWith('/attachments/file'),
      );
      expect(download.url.hasQuery, isFalse);
      await tester.tap(find.byTooltip('첨부파일 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.notice['attachments'], isEmpty);
    },
  );

  testWidgets(
    'a member has no notice management controls and can leave the club',
    (tester) async {
      final server = ClubServer()..owner = false;
      final api = server.api();
      await launch(
        tester,
        api,
        ClubNoticeDetailScreen(clubId: clubId, noticeId: noticeId, api: api),
      );
      expect(find.byTooltip('공지 관리'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await launch(tester, api, ClubSettingsScreen(clubId: clubId, api: api));
      expect(find.text('클럽 정보 저장'), findsNothing);
      await tester.tap(find.text('클럽 탈퇴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.joined, isFalse);
    },
  );

  testWidgets(
    'owner settings patch actual club information and keep close separate',
    (tester) async {
      final server = ClubServer();
      final client = server.api();
      await launch(
        tester,
        client,
        ClubSettingsScreen(clubId: clubId, api: client),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '클럽 이름'),
        '저녁 러너스',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('클럽 정보 저장'));
      await tester.pumpAndSettle();
      expect(server.club['name'], '저녁 러너스');
      expect(server.joined, isTrue);
      expect(find.text('클럽 폐쇄'), findsOneWidget);
    },
  );

  testWidgets(
    'logout disposes a pending private page before its response arrives',
    (tester) async {
      final session = UiAuth(), pending = Completer<http.Response>();
      final api = RunlineApi(
        session: session,
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) => pending.future),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ClubSessionGate(
            api: api,
            child: ClubNoticeDetailScreen(
              clubId: clubId,
              noticeId: noticeId,
              api: api,
            ),
          ),
        ),
      );
      await tester.pump();
      session.logout();
      await tester.pump();
      expect(find.text('로그인 후 클럽을 이용해주세요.'), findsOneWidget);
      pending.complete(
        response({
          'notice': ClubServer().notice,
          'membership': {'role': 'owner'},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('주말 모임 안내'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('club home and navigation fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ClubServer().api();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClubScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('멤버'));
    await tester.pumpAndSettle();
    expect(find.text('민수'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search filters and public club introduction lead to immediate joining',
    (tester) async {
      final server = ClubServer()..joined = false;
      final api = server.api();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClubScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('클럽 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '한강');
      await tester.enterText(find.byType(TextField).at(1), '서울');
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      final search = server.calls.last;
      expect(search.url.queryParameters, {'query': '한강', 'region': '서울'});
      await tester.tap(find.text('한강 러너스'));
      await tester.pumpAndSettle();
      expect(find.text('클럽 소개'), findsOneWidget);
      await tester.tap(find.text('즉시 가입'));
      await tester.pumpAndSettle();
      expect(server.joined, isTrue);
      expect(find.byTooltip('클럽 검색'), findsNothing);
    },
  );

  testWidgets('kicking a member refreshes the member list after confirmation', (
    tester,
  ) async {
    final server = ClubServer();
    final api = server.api();
    await launch(
      tester,
      api,
      ClubMembersScreen(
        clubId: clubId,
        membership: server.membership,
        api: api,
      ),
    );
    await tester.tap(find.byTooltip('멤버 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('강퇴'));
    await tester.pumpAndSettle();
    expect(server.kicked, isFalse);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(server.kicked, isTrue);
    expect(find.text('민수'), findsNothing);
  });

  testWidgets(
    'closing a club uses the owner endpoint only after confirmation',
    (tester) async {
      final server = ClubServer();
      final api = server.api();
      await launch(tester, api, ClubSettingsScreen(clubId: clubId, api: api));
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '클럽 폐쇄'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '클럽 폐쇄'));
      await tester.pumpAndSettle();
      expect(server.joined, isTrue);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.joined, isFalse);
      expect(
        server.calls.any(
          (c) => c.method == 'DELETE' && c.url.path == '/api/v1/clubs/$clubId',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'the run creator cancels the event instead of withdrawing attendance',
    (tester) async {
      final server = ClubServer();
      server.run['creator_membership_id'] = mine;
      final api = server.api();
      await launch(
        tester,
        api,
        ClubRunDetailScreen(clubId: clubId, runId: runId, api: api),
      );
      expect(find.byTooltip('러닝 수정'), findsOneWidget);
      expect(find.text('참가 취소'), findsNothing);
      await tester.tap(find.text('러닝 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.run['state'], 'cancelled');
      expect(find.byTooltip('러닝 수정'), findsNothing);
    },
  );

  testWidgets('profile nickname updates share the existing authenticated API', (
    tester,
  ) async {
    final server = ClubServer();
    final api = server.api();
    await launch(tester, api, ClubProfileEditorScreen(api: api));
    await tester.enterText(find.widgetWithText(TextFormField, '닉네임'), '달리는 사람');
    await tester.tap(find.text('프로필 저장'));
    await tester.pumpAndSettle();
    final sent = server.calls.singleWhere((c) => c.method == 'PATCH');
    expect(sent.url.path, '/api/v1/me/profile');
    expect(jsonDecode(sent.body), {'nickname': '달리는 사람'});
  });

  testWidgets(
    'a partial photo failure retries remaining uploads without duplicating the notice',
    (tester) async {
      final server = ClubServer();
      var attempts = 0;
      final api = RunlineApi(
        session: UiAuth(),
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/attachments')) {
            attempts++;
            if (attempts == 2) {
              return response({
                'error': {'message': 'temporary'},
              }, 500);
            }
          }
          return server.handle(request);
        }),
      );
      await launch(
        tester,
        api,
        ClubNoticeEditorScreen(clubId: clubId, api: api),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '공지 제목'),
        '사진 모음',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '공지 내용'),
        '오늘의 러닝',
      );
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uw0AAAAASUVORK5CYII=',
      );
      final image = OptimizedUploadImage(
        bytes: bytes,
        contentType: 'image/png',
        filename: 'image.png',
        width: 1,
        height: 1,
      );
      tester
          .widget<UploadImagePicker>(find.byType(UploadImagePicker))
          .onChanged([image, image]);
      tester.testTextInput.hide();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('저장'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<UploadImagePicker>(find.byType(UploadImagePicker))
            .lockedCount,
        1,
      );
      await tester.scrollUntilVisible(
        find.text('사진 업로드 다시 시도'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('사진 업로드 다시 시도'));
      await tester.pumpAndSettle();
      expect(attempts, 3);
      expect(
        server.calls.where(
          (c) => c.method == 'POST' && c.url.path.endsWith('/notices'),
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'switching account closes private forms and confirmation content',
    (tester) async {
      final server = ClubServer();
      final session = UiAuth();
      final api = server.api(session);
      await launch(
        tester,
        api,
        ClubMembersScreen(
          clubId: clubId,
          membership: server.membership,
          api: api,
        ),
      );
      await tester.tap(find.byTooltip('멤버 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('클럽장 위임'));
      await tester.pumpAndSettle();
      session.switchAccount('someone-else');
      await tester.pumpAndSettle();
      expect(find.textContaining('민수'), findsNothing);
      expect(find.text('확인'), findsNothing);
      expect(server.owner, isTrue);
    },
  );

  test('an old account request cannot send credentials for a newly signed in account', () async {
    final session = PendingAuth();
    var requests = 0;
    final api = RunlineApi(
      session: session,
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient((_) async {
        requests++;
        return response({});
      }),
    );
    final result = api.json(
      '/clubs/$clubId/notices',
      method: 'POST',
      body: {'title': 'old'},
    );
    session.switchAccount('another-user');
    session.pending.complete(true);
    await expectLater(result, throwsA(isA<RunlineApiException>()));
    expect(requests, 0);
  });

  test(
    'pagination preserves entries on failure and retries the same cursor',
    () async {
      var fail = true;
      final requests = <Uri>[];
      final api = RunlineApi(
        session: UiAuth(),
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.queryParameters['cursor'] == null) {
            return response({
              'items': [
                {'id': '1'},
              ],
              'nextCursor': 'a+b/=',
            });
          }
          if (fail) {
            fail = false;
            return response({
              'error': {'message': 'retry'},
            }, 500);
          }
          return response({
            'items': [
              {'id': '1'},
              {'id': '2'},
            ],
            'nextCursor': null,
          });
        }),
      );
      final page = ClubPageController(api, '/clubs?query=서울');
      addTearDown(page.dispose);
      await page.load();
      await page.load(more: true);
      expect(page.items, [
        {'id': '1'},
      ]);
      expect(page.failedMore, isTrue);
      await page.load(more: page.failedMore);
      expect(page.items.map((item) => item['id']), ['1', '2']);
      expect(requests.last.queryParameters, {'query': '서울', 'cursor': 'a+b/='});
    },
  );

  test('a changed filter discards an older in-flight page', () async {
    final old = Completer<http.Response>();
    final api = RunlineApi(
      session: UiAuth(),
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient(
        (request) => request.url.queryParameters['query'] == 'old'
            ? old.future
            : Future.value(
                response({
                  'items': [
                    {'id': 'new'},
                  ],
                  'nextCursor': null,
                }),
              ),
      ),
    );
    final page = ClubPageController(api, '/clubs?query=old');
    addTearDown(page.dispose);
    final first = page.load();
    page.path = '/clubs?query=new';
    await page.load();
    old.complete(
      response({
        'items': [
          {'id': 'old'},
        ],
        'nextCursor': null,
      }),
    );
    await first;
    expect(page.items.single['id'], 'new');
  });
}
