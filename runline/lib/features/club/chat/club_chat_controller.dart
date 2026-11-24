import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../shared/media/runline_api.dart';

class ClubChatMessage {
  ClubChatMessage.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      sequence = BigInt.parse(json['sequence'] as String),
      membershipId = json['sender_membership_id'] as String,
      clientMessageId = json['client_message_id'] as String,
      nickname = json['nickname'] as String,
      content = json['content'] as String,
      createdAt = DateTime.parse(json['created_at'] as String);
  final String id;
  final BigInt sequence;
  final String membershipId;
  final String clientMessageId;
  final String nickname;
  final String content;
  final DateTime createdAt;
}

enum PendingChatStatus { queued, sending, failed }

class PendingChatMessage {
  PendingChatMessage(this.id, this.content);
  final String id;
  final String content;
  PendingChatStatus status = PendingChatStatus.queued;
  Timer? acknowledgement;
}

enum ChatConnectionState {
  connecting,
  connected,
  offline,
  authRequired,
  accessDenied,
}

class ClubChatController extends ChangeNotifier {
  ClubChatController({
    required this.clubId,
    RunlineApi? api,
    WebSocketChannel Function(Uri)? channelFactory,
  }) : api = api ?? RunlineApi.instance,
       _channelFactory = channelFactory ?? WebSocketChannel.connect {
    this.api.session.addListener(_sessionChanged);
  }

  final String clubId;
  final RunlineApi api;
  final WebSocketChannel Function(Uri) _channelFactory;
  final _messages = <BigInt, ClubChatMessage>{};
  final _pending = <String, PendingChatMessage>{};
  List<ClubChatMessage> get messages =>
      _messages.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
  List<PendingChatMessage> get pending => _pending.values.toList();
  String? membershipId;
  String? error;
  ChatConnectionState connection = ChatConnectionState.offline;
  bool hasOlder = false;
  bool loadingOlder = false;
  BigInt? _oldest;
  BigInt? _caughtUp;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  Timer? _heartbeat;
  Timer? _readTimer;
  Timer? _authTimeout;
  int _generation = 0;
  int _attempts = 0;
  bool _disposed = false;
  bool _paused = false;
  bool _reading = true;
  bool _syncing = false;
  bool _syncAgain = false;

  bool get canSend =>
      !_paused &&
      api.session.isSignedIn &&
      connection != ChatConnectionState.authRequired &&
      connection != ChatConnectionState.accessDenied;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    _stop();
    _clear();
    _attempts = 0;
    if (!_paused) unawaited(connect());
    _notify();
  }

  void _clear() {
    _messages.clear();
    for (final item in _pending.values) {
      item.acknowledgement?.cancel();
    }
    _pending.clear();
    membershipId = null;
    _caughtUp = null;
    _oldest = null;
    hasOlder = false;
  }

  void _stop() {
    _generation++;
    _reconnect?.cancel();
    _heartbeat?.cancel();
    _readTimer?.cancel();
    _authTimeout?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final previous = _channel;
    _channel = null;
    if (previous != null) {
      unawaited(previous.sink.close(1000).catchError((Object _) {}));
    }
    for (final item in _pending.values) {
      item.acknowledgement?.cancel();
      if (item.status == PendingChatStatus.sending) {
        item.status = PendingChatStatus.queued;
      }
    }
    _syncing = false;
    _syncAgain = false;
  }

  Future<void> connect() async {
    if (_disposed || _paused) return;
    _stop();
    if (!api.session.isSignedIn) {
      _clear();
      connection = ChatConnectionState.authRequired;
      error = '로그인 후 채팅을 이용해주세요.';
      _notify();
      return;
    }
    final generation = _generation;
    connection = ChatConnectionState.connecting;
    error = null;
    _notify();
    try {
      final endpoint = api.endpoint('/api/v1/clubs/$clubId/chat/socket');
      final channel = _channelFactory(
        endpoint.replace(scheme: endpoint.scheme == 'https' ? 'wss' : 'ws'),
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        (dynamic data) {
          if (generation == _generation && !_disposed) {
            _receive(data, generation);
          }
        },
        onDone: () => _lost(generation, channel.closeCode),
        onError: (Object _) => _lost(generation, channel.closeCode),
      );
      await channel.ready.timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation) return;
      channel.sink.add(
        jsonEncode({'type': 'auth', 'accessToken': api.session.accessToken}),
      );
      _authTimeout = Timer(
        const Duration(seconds: 8),
        () => _lost(generation, null),
      );
    } catch (_) {
      _lost(generation, null);
    }
  }

  void _lost(int generation, int? code) {
    if (_disposed || generation != _generation) return;
    _stop();
    if (code == 4001 || code == 4003) {
      _clear();
      connection = code == 4001
          ? ChatConnectionState.authRequired
          : ChatConnectionState.accessDenied;
      error = code == 4001
          ? '로그인이 만료되었어요. 다시 로그인해주세요.'
          : '이 클럽의 채팅을 이용할 수 없어요.';
    } else {
      connection = ChatConnectionState.offline;
      error = '연결이 끊겼어요. 다시 연결하고 있어요.';
      if (!_paused && _attempts < 5) {
        final delay = min(30, 1 << _attempts++);
        _reconnect = Timer(
          Duration(milliseconds: delay * 1000 + Random().nextInt(400)),
          () => unawaited(connect()),
        );
      }
    }
    _notify();
  }

  void _receive(dynamic data, int generation) {
    try {
      if (data is! String) throw const FormatException();
      final body = jsonDecode(data) as Map<String, dynamic>;
      switch (body['type']) {
        case 'ready':
          _authTimeout?.cancel();
          final state = body['state'] as Map<String, dynamic>;
          if (membershipId != null && membershipId != state['membership_id']) {
            _clear();
          }
          membershipId = state['membership_id'] as String;
          connection = ChatConnectionState.connected;
          _attempts = 0;
          error = null;
          _heartbeat = Timer.periodic(
            const Duration(seconds: 25),
            (_) => _sendFrame({'type': 'ping'}),
          );
          unawaited(_sync(generation));
        case 'message' || 'ack':
          _merge(body['message'] as Map<String, dynamic>);
          _advance();
          if (_caughtUp != null &&
              _messages.keys.any((seq) => seq > _caughtUp! + BigInt.one)) {
            unawaited(_sync(generation));
          }
          _scheduleRead();
        case 'pong':
          // Anti-entropy also recovers a commit whose real-time broadcast failed.
          unawaited(_sync(generation));
        case 'error':
          final item = _pending[body['clientMessageId']];
          if (item != null) {
            item.acknowledgement?.cancel();
            item.status = PendingChatStatus.failed;
          }
          error = body['code'] == 'CHAT_RATE_LIMIT'
              ? '메시지를 너무 빠르게 보냈어요. 잠시 후 다시 시도해주세요.'
              : '메시지를 보내지 못했어요. 다시 시도해주세요.';
      }
      _notify();
    } catch (_) {
      _lost(generation, null);
    }
  }

  void _merge(Map<String, dynamic> json) {
    final message = ClubChatMessage.fromJson(json);
    _messages[message.sequence] = message;
    if (message.membershipId == membershipId) {
      _pending.remove(message.clientMessageId)?.acknowledgement?.cancel();
    }
  }

  void _advance() {
    if (_caughtUp == null) return;
    while (_messages.containsKey(_caughtUp! + BigInt.one)) {
      _caughtUp = _caughtUp! + BigInt.one;
    }
  }

  Future<void> _sync(int generation) async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    if (generation != _generation || _disposed) return;
    _syncing = true;
    try {
      var more = true;
      while (more && generation == _generation && !_disposed) {
        final initial = _caughtUp == null;
        final query = initial ? '?limit=50' : '?after=$_caughtUp&limit=100';
        final result = await api.json('/clubs/$clubId/chat/messages$query');
        if (generation != _generation || _disposed) return;
        if (result['state']['membership_id'] != membershipId) {
          await connect();
          return;
        }
        final items = (result['items'] as List).cast<Map<String, dynamic>>();
        for (final item in items) {
          _merge(item);
        }
        if (initial) {
          _caughtUp = BigInt.parse(result['state']['last_sequence'] as String);
          hasOlder = result['hasMore'] as bool;
          _oldest = items.isEmpty
              ? null
              : items
                    .map((item) => BigInt.parse(item['sequence'] as String))
                    .reduce((a, b) => a < b ? a : b);
          more = false;
        } else {
          if (items.isNotEmpty) {
            _caughtUp = BigInt.parse(items.last['sequence'] as String);
          }
          more = result['hasMore'] as bool;
        }
        _advance();
        _notify();
      }
      if (generation == _generation && !_disposed) {
        for (final item in _pending.values.toList()) {
          if (item.status == PendingChatStatus.queued) _transmit(item);
        }
        _scheduleRead();
      }
    } catch (error) {
      if (generation != _generation || _disposed) return;
      if (error is RunlineApiException &&
          [401, 403, 404].contains(error.statusCode)) {
        _lost(generation, error.statusCode == 401 ? 4001 : 4003);
      } else {
        this.error = '대화를 불러오지 못했어요. 다시 시도해주세요.';
        _notify();
      }
    } finally {
      if (generation == _generation) {
        _syncing = false;
        if (_syncAgain) {
          _syncAgain = false;
          unawaited(_sync(generation));
        }
      }
    }
  }

  Future<void> loadOlder() async {
    if (!hasOlder || loadingOlder || _oldest == null) return;
    final generation = _generation;
    loadingOlder = true;
    _notify();
    try {
      final result = await api.json(
        '/clubs/$clubId/chat/messages?before=$_oldest&limit=50',
      );
      if (_disposed || generation != _generation) return;
      if (result['state']['membership_id'] != membershipId) {
        await connect();
        return;
      }
      final items = (result['items'] as List).cast<Map<String, dynamic>>();
      for (final item in items) {
        _merge(item);
      }
      if (items.isNotEmpty) {
        _oldest = BigInt.parse(items.last['sequence'] as String);
      }
      hasOlder = result['hasMore'] as bool;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      if (error is RunlineApiException &&
          [401, 403, 404].contains(error.statusCode)) {
        _lost(generation, error.statusCode == 401 ? 4001 : 4003);
      } else {
        this.error = '이전 대화를 불러오지 못했어요.';
      }
    } finally {
      if (!_disposed) {
        loadingOlder = false;
        _notify();
      }
    }
  }

  String? send(String content) {
    final value = content.trim();
    if (!canSend || value.isEmpty) return '연결 상태를 확인해주세요.';
    if (value.runes.length > 2000 ||
        utf8.encode(value).length > 8000 ||
        value.contains('\u0000')) {
      return '메시지는 2000자 이내로 입력해주세요.';
    }
    if (_pending.length >= 20) return '대기 중인 메시지를 먼저 확인해주세요.';
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final item = PendingChatMessage(id, value);
    _pending[id] = item;
    if (connection == ChatConnectionState.connected && _caughtUp != null) {
      _transmit(item);
    }
    _notify();
    return null;
  }

  void retry(String id) {
    final item = _pending[id];
    if (item == null || !canSend) return;
    item.status = PendingChatStatus.queued;
    if (connection == ChatConnectionState.connected && _caughtUp != null) {
      _transmit(item);
    }
    _notify();
  }

  void _sendFrame(Map<String, dynamic> frame) {
    try {
      _channel?.sink.add(jsonEncode(frame));
    } catch (_) {
      _lost(_generation, null);
    }
  }

  void _transmit(PendingChatMessage item) {
    item.status = PendingChatStatus.sending;
    _sendFrame({
      'type': 'send',
      'clientMessageId': item.id,
      'content': item.content,
    });
    item.acknowledgement?.cancel();
    item.acknowledgement = Timer(const Duration(seconds: 10), () {
      if (!_disposed && _pending.containsKey(item.id)) {
        item.status = PendingChatStatus.failed;
        _notify();
      }
    });
  }

  void setReading(bool reading) {
    _reading = reading;
    if (reading) _scheduleRead();
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    if (!_reading ||
        _paused ||
        _caughtUp == null ||
        connection != ChatConnectionState.connected) {
      return;
    }
    final generation = _generation;
    final seq = _caughtUp.toString();
    _readTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await api.json(
          '/clubs/$clubId/chat/read',
          method: 'POST',
          body: {'sequence': seq},
        );
      } catch (_) {
        /* Read state can be retried on the next delivery/reconnect. */
      }
      if (generation != _generation) return;
    });
  }

  void setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (paused) {
      _stop();
      connection = ChatConnectionState.offline;
    } else {
      unawaited(connect());
    }
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    api.session.removeListener(_sessionChanged);
    _stop();
    _clear();
    super.dispose();
  }
}
