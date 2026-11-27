import 'dart:async';

import 'package:flutter/material.dart';

import 'club_chat_controller.dart';
import '../../../shared/media/runline_api.dart';

class ClubChatScreen extends StatefulWidget {
  const ClubChatScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.controller,
    this.api,
  });
  final String clubId;
  final String clubName;
  final ClubChatController? controller;
  final RunlineApi? api;
  @override
  State<ClubChatScreen> createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen>
    with WidgetsBindingObserver {
  late final ClubChatController _chat;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat =
        widget.controller ??
        ClubChatController(clubId: widget.clubId, api: widget.api);
    _chat.addListener(_changed);
    _scroll.addListener(_reading);
    unawaited(_chat.connect());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _reading() {
    _chat.setReading(
      _foreground && (!_scroll.hasClients || _scroll.offset < 80),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _chat.setPaused(!_foreground);
    _reading();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    if (widget.controller == null) _chat.dispose();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final error = _chat.send(_input.text);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _input.clear();
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  Widget _bubble(
    String content, {
    required bool mine,
    String? name,
    String? footer,
    VoidCallback? retry,
  }) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: mine
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name != null)
            Text(name, style: Theme.of(context).textTheme.labelSmall),
          SelectableText(content),
          if (footer != null)
            Text(footer, style: Theme.of(context).textTheme.labelSmall),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('다시 보내기')),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final messages = _chat.messages.reversed.toList();
    final pending = _chat.pending.reversed.toList();
    final connected = _chat.connection == ChatConnectionState.connected;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clubName} 채팅'),
        actions: [
          if (!connected)
            IconButton(
              tooltip: '다시 연결',
              onPressed: _chat.connect,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_chat.error != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_chat.error!),
            ),
          if (_chat.connection == ChatConnectionState.connecting)
            const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              itemCount: pending.length + messages.length + 1,
              itemBuilder: (context, index) {
                if (index < pending.length) {
                  final item = pending[index];
                  return _bubble(
                    item.content,
                    mine: true,
                    footer: switch (item.status) {
                      PendingChatStatus.queued => '전송 대기',
                      PendingChatStatus.sending => '전송 중',
                      PendingChatStatus.failed => '전송 실패',
                    },
                    retry: item.status == PendingChatStatus.failed
                        ? () => _chat.retry(item.id)
                        : null,
                  );
                }
                final messageIndex = index - pending.length;
                if (messageIndex == messages.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: _chat.hasOlder
                        ? TextButton(
                            onPressed: _chat.loadingOlder
                                ? null
                                : _chat.loadOlder,
                            child: Text(
                              _chat.loadingOlder ? '불러오는 중…' : '이전 대화 보기',
                            ),
                          )
                        : const Center(child: Text('가입 이후의 대화만 표시돼요.')),
                  );
                }
                final item = messages[messageIndex];
                final time = TimeOfDay.fromDateTime(item.createdAt.toLocal())
                    .format(context);
                return _bubble(
                  item.content,
                  mine: item.membershipId == _chat.membershipId,
                  name: item.nickname,
                  footer: '$time · 저장됨',
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: _chat.canSend,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: '클럽원에게 메시지를 보내보세요',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '메시지 보내기',
                    onPressed: _chat.canSend ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
