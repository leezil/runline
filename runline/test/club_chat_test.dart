import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:runline/features/club/chat/club_chat_controller.dart';
import 'package:runline/features/club/chat/club_chat_screen.dart';
import 'package:runline/shared/media/runline_api.dart';

class FakeSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  @override
  int? closeCode;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  Future<void> get ready async {}
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  late final WebSocketSink sink = FakeSink(this);
  void receive(Map<String, dynamic> data) => incoming.add(jsonEncode(data));
  Future<void> serverClose(int code) async {
    closeCode = code;
    await incoming.close();
  }
}

class FakeSink implements WebSocketSink {
  FakeSink(this.socket);
  final FakeSocket socket;
  final _done = Completer<void>();
  @override
  Future<void> get done => _done.future;
  @override
  void add(dynamic data) {
    socket.sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      socket.incoming.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
    if (!socket.incoming.isClosed) await socket.incoming.close();
  }
}

Map<String, dynamic> message(
  int sequence, {
  String? clientId,
  String member = 'other',
  String? content,
}) => {
  'id': 'message-$sequence',
  'sequence': '$sequence',
  'sender_membership_id': member,
  'client_message_id': clientId ?? 'client-$sequence',
  'nickname': '러너',
  'content': content ?? '대화 $sequence',
  'created_at': '2026-11-23T00:00:00Z',
};
Map<String, dynamic> state(int last) => {
  'membership_id': 'member',
  'user_id': 'user',
  'visible_after_sequence': '0',
  'last_read_sequence': '0',
  'last_sequence': '$last',
  'unread_count': last,
};
http.Response history(List<Map<String, dynamic>> items, int last) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'ok': true,
          'items': items,
          'hasMore': false,
          'nextSequence': null,
          'state': state(last),
        }),
      ),
      200,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'authenticates without URL tokens and orders history by server sequence',
    () async {
      final socket = FakeSocket();
      final session = RunlineSession()..setAccessToken('rla_${'a' * 64}');
      final api = RunlineApi(
        session: session,
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) async => history([message(2), message(1)], 2)),
      );
      final controller = ClubChatController(
        clubId: 'club',
        api: api,
        channelFactory: (uri) {
          expect(uri.scheme, 'wss');
          expect(uri.hasQuery, isFalse);
          return socket;
        },
      );
      addTearDown(controller.dispose);
      controller.setReading(false);
      await controller.connect();
      expect(socket.sent.single, {
        'type': 'auth',
        'accessToken': session.accessToken,
      });
      expect(controller.messages, isEmpty);
      socket.receive({'type': 'ready', 'state': state(2)});
      await settle();
      expect(controller.messages.map((item) => item.sequence.toInt()), [1, 2]);
      expect(controller.connection, ChatConnectionState.connected);
    },
  );

  test('keeps outgoing messages pending until committed ack and retries using the same ID', () async {
    final socket = FakeSocket();
    final api = RunlineApi(
      session: RunlineSession()..setAccessToken('token'),
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient((_) async => history([], 0)),
    );
    final controller = ClubChatController(
      clubId: 'club',
      api: api,
      channelFactory: (_) => socket,
    );
    addTearDown(controller.dispose);
    controller.setReading(false);
    await controller.connect();
    socket.receive({'type': 'ready', 'state': state(0)});
    await settle();
    expect(controller.send('안녕하세요'), isNull);
    final id = controller.pending.single.id;
    expect(controller.pending.single.status, PendingChatStatus.sending);
    expect(controller.messages, isEmpty);
    socket.receive({
      'type': 'error',
      'code': 'CHAT_RATE_LIMIT',
      'clientMessageId': id,
    });
    await settle();
    expect(controller.pending.single.status, PendingChatStatus.failed);
    controller.retry(id);
    final sends = socket.sent
        .where((value) => value['type'] == 'send')
        .toList();
    expect(sends, hasLength(2));
    expect(sends[0], sends[1]);
    socket.receive({
      'type': 'ack',
      'message': message(1, member: 'member', clientId: id, content: '안녕하세요'),
    });
    await settle();
    expect(controller.pending, isEmpty);
    expect(controller.messages.single.content, '안녕하세요');
    socket.receive({
      'type': 'message',
      'message': message(1, member: 'member', clientId: id, content: '안녕하세요'),
    });
    await settle();
    expect(controller.messages, hasLength(1));
  });

  test('recovers a missing sequence without skipping it when a later live message arrives', () async {
    final socket = FakeSocket();
    final requests = <String>[];
    final api = RunlineApi(
      session: RunlineSession()..setAccessToken('token'),
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient((request) async {
        requests.add(request.url.query);
        return request.url.queryParameters.containsKey('after')
            ? history([message(2), message(3)], 3)
            : history([message(1)], 1);
      }),
    );
    final controller = ClubChatController(
      clubId: 'club',
      api: api,
      channelFactory: (_) => socket,
    );
    addTearDown(controller.dispose);
    controller.setReading(false);
    await controller.connect();
    socket.receive({'type': 'ready', 'state': state(1)});
    await settle();
    socket.receive({'type': 'message', 'message': message(3)});
    await settle();
    expect(requests, contains('after=1&limit=100'));
    expect(controller.messages.map((item) => item.sequence.toInt()), [1, 2, 3]);
  });

  test(
    'discards in-flight history and closes the socket when logging out',
    () async {
      final socket = FakeSocket();
      final response = Completer<http.Response>();
      final session = RunlineSession()..setAccessToken('token');
      final api = RunlineApi(
        session: session,
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) => response.future),
      );
      final controller = ClubChatController(
        clubId: 'club',
        api: api,
        channelFactory: (_) => socket,
      );
      addTearDown(controller.dispose);
      controller.setReading(false);
      await controller.connect();
      socket.receive({'type': 'ready', 'state': state(1)});
      await settle();
      session.setAccessToken(null);
      response.complete(history([message(1, content: '비공개')], 1));
      await settle();
      expect(controller.messages, isEmpty);
      expect(controller.pending, isEmpty);
      expect(controller.connection, ChatConnectionState.authRequired);
      expect(socket.incoming.isClosed, isTrue);
    },
  );

  test(
    'clears history and does not reconnect when membership is revoked',
    () async {
      final socket = FakeSocket();
      var connections = 0;
      final api = RunlineApi(
        session: RunlineSession()..setAccessToken('token'),
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient((_) async => history([message(1)], 1)),
      );
      final controller = ClubChatController(
        clubId: 'club',
        api: api,
        channelFactory: (_) {
          connections++;
          return socket;
        },
      );
      addTearDown(controller.dispose);
      controller.setReading(false);
      await controller.connect();
      socket.receive({'type': 'ready', 'state': state(1)});
      await settle();
      await socket.serverClose(4003);
      await settle();
      expect(controller.messages, isEmpty);
      expect(controller.connection, ChatConnectionState.accessDenied);
      expect(controller.canSend, isFalse);
      expect(connections, 1);
    },
  );

  testWidgets('shows text and send state without overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final socket = FakeSocket();
    final api = RunlineApi(
      session: RunlineSession()..setAccessToken('token'),
      baseUri: Uri.parse('https://api.example.com'),
      client: MockClient(
        (_) async => history([message(1, content: '함께 달려요')], 1),
      ),
    );
    final controller = ClubChatController(
      clubId: 'club',
      api: api,
      channelFactory: (_) => socket,
    );
    addTearDown(controller.dispose);
    controller.setReading(false);
    await tester.pumpWidget(
      MaterialApp(
        home: ClubChatScreen(
          clubId: 'club',
          clubName: '러닝 클럽',
          controller: controller,
        ),
      ),
    );
    await tester.pump();
    socket.receive({'type': 'ready', 'state': state(1)});
    await tester.pumpAndSettle();
    expect(find.text('함께 달려요'), findsOneWidget);
    expect(find.byTooltip('메시지 보내기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
