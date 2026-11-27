import 'package:flutter/material.dart';

import '../../shared/media/image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import 'feed_profile_screen.dart';
import 'widgets/feed_avatar.dart';

enum _PostAction { edit, delete }

/// Displays the stored post, without prototype comments/likes or sample photos.
class FeedPostScreen extends StatefulWidget {
  const FeedPostScreen({
    super.key,
    required this.postId,
    required this.api,
    this.onFollowChanged,
  });
  final String postId;
  final RunlineApi api;
  final VoidCallback? onFollowChanged;
  @override
  State<FeedPostScreen> createState() => _FeedPostScreenState();
}

class _FeedPostScreenState extends State<FeedPostScreen> {
  Map<String, dynamic>? _post;
  String? _error;
  int _generation = 0;
  bool _loading = false;
  bool _editing = false;
  bool _confirmingDelete = false;
  bool _deleting = false;
  Object? _deleteOperation;
  String? _accountId;
  int _accountEpoch = 0;

  bool get _ownsPost =>
      widget.api.session.isSignedIn &&
      widget.api.session.userId != null &&
      _post?['author']?['id'] == widget.api.session.userId;
  bool get _busy => _editing || _confirmingDelete || _deleting;

  @override
  void initState() {
    super.initState();
    _accountId = widget.api.session.userId;
    widget.api.session.addListener(_sessionChanged);
    widget.api.profileChanges.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(FeedPostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      oldWidget.api.session.removeListener(_sessionChanged);
      oldWidget.api.profileChanges.removeListener(_load);
      widget.api.session.addListener(_sessionChanged);
      widget.api.profileChanges.addListener(_load);
    }
    if (oldWidget.api != widget.api || oldWidget.postId != widget.postId) {
      _accountId = widget.api.session.userId;
      _resetActions();
      _load();
    }
  }

  @override
  void dispose() {
    widget.api.session.removeListener(_sessionChanged);
    widget.api.profileChanges.removeListener(_load);
    super.dispose();
  }

  void _resetActions() {
    _accountEpoch++;
    _deleteOperation = null;
    _editing = _confirmingDelete = _deleting = false;
  }

  void _sessionChanged() {
    final account = widget.api.session.userId;
    if (account != _accountId || !widget.api.session.isSignedIn) {
      _accountId = account;
      _resetActions();
    }
    _load();
  }

  bool _currentAccount(
    RunlineApi api,
    String postId,
    String? owner,
    int epoch,
  ) =>
      mounted &&
      identical(api, widget.api) &&
      postId == widget.postId &&
      epoch == _accountEpoch &&
      api.session.isSignedIn &&
      owner != null &&
      owner == api.session.userId;

  Future<void> _load() async {
    if (_deleting) return;
    final generation = ++_generation;
    setState(() {
      _post = null;
      _error = null;
      _loading = widget.api.session.isSignedIn;
    });
    if (!widget.api.session.isSignedIn) return;
    try {
      final data = await widget.api.json(
        '/feed/posts/${Uri.encodeComponent(widget.postId)}',
      );
      if (mounted && generation == _generation) {
        setState(() => _post = data['post'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is RunlineApiException
              ? error.message
              : '게시물을 불러오지 못했어요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editPost() async {
    if (!_ownsPost || _busy) return;
    final post = _post!;
    final api = widget.api;
    final owner = api.session.userId;
    final postId = widget.postId;
    final epoch = _accountEpoch;
    setState(() => _editing = true);
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ImageComposeScreen(
            kind: ImageComposeKind.feed,
            api: api,
            post: post,
          ),
        ),
      );
      if (saved == true && _currentAccount(api, postId, owner, epoch)) {
        await _load();
      }
    } finally {
      if (_currentAccount(api, postId, owner, epoch)) {
        setState(() => _editing = false);
      }
    }
  }

  Future<void> _deletePost() async {
    if (!_ownsPost || _busy) return;
    final api = widget.api;
    final owner = api.session.userId;
    final postId = widget.postId;
    final epoch = _accountEpoch;
    setState(() => _confirmingDelete = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: api.session,
        builder: (context, _) => AlertDialog(
          title: const Text('게시글 삭제'),
          content: const Text('게시글을 삭제할까요? 삭제한 게시글은 복구할 수 없어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: _currentAccount(api, postId, owner, epoch)
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
    if (!_currentAccount(api, postId, owner, epoch)) return;
    setState(() => _confirmingDelete = false);
    if (confirmed != true) return;
    final operation = Object();
    setState(() {
      _deleteOperation = operation;
      _deleting = true;
    });
    try {
      await api.json(
        '/feed/posts/${Uri.encodeComponent(postId)}',
        method: 'DELETE',
      );
      if (!mounted) return;
      if (_currentAccount(api, postId, owner, epoch) &&
          identical(_deleteOperation, operation)) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted &&
          _currentAccount(api, postId, owner, epoch) &&
          identical(_deleteOperation, operation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is RunlineApiException
                  ? error.message
                  : '게시글을 삭제하지 못했어요. 다시 시도해주세요.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && identical(_deleteOperation, operation)) {
        setState(() {
          _deleteOperation = null;
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('게시물'),
          actions: [
            if (_ownsPost)
              PopupMenuButton<_PostAction>(
                tooltip: '게시글 메뉴',
                enabled: !_busy,
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case _PostAction.edit:
                      _editPost();
                    case _PostAction.delete:
                      _deletePost();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _PostAction.edit,
                    child: Text('게시글 수정'),
                  ),
                  PopupMenuItem(
                    value: _PostAction.delete,
                    child: Text(
                      '게시글 삭제',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_deleting) const LinearProgressIndicator(),
              if (!widget.api.session.isSignedIn)
                const Text('로그인 후 게시물을 확인해주세요.'),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                TextButton(onPressed: _load, child: Text('$_error 다시 시도')),
              if (post != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FeedAvatar(
                    name: post['author']['nickname'] as String,
                    avatarUrl: post['author']['avatarUrl'] as String?,
                    api: widget.api,
                  ),
                  title: Text(post['author']['nickname'] as String),
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => FeedProfileScreen(
                              userId: post['author']['id'] as String,
                              api: widget.api,
                              onFollowChanged: widget.onFollowChanged,
                            ),
                          ),
                        ),
                ),
                if ((post['body'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(post['body'] as String),
                  ),
                for (final media in post['media'] as List)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 320,
                      child: InteractiveViewer(
                        child: RunlineImage(
                          path: media['url'] as String,
                          api: widget.api,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
