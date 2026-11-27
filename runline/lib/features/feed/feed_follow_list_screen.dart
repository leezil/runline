import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import 'feed_profile_screen.dart';
import 'widgets/feed_avatar.dart';

class FeedFollowListScreen extends StatefulWidget {
  const FeedFollowListScreen({
    super.key,
    required this.userId,
    required this.following,
    required this.ownProfile,
    required this.api,
    this.onFollowChanged,
  });

  final String userId;
  final bool following;
  final bool ownProfile;
  final RunlineApi api;
  final VoidCallback? onFollowChanged;

  @override
  State<FeedFollowListScreen> createState() => _FeedFollowListScreenState();
}

class _FeedFollowListScreenState extends State<FeedFollowListScreen> {
  final _users = <Map<String, dynamic>>[];
  final _pending = <String, Object>{};
  final _removed = <String>{};
  final _mutationErrors = <String, String>{};
  String? _cursor;
  String? _error;
  bool _loading = false;
  bool _failedReset = true;
  int _generation = 0;

  bool get _canUnfollow =>
      widget.following &&
      widget.ownProfile &&
      (widget.api.session.userId == null ||
          widget.api.session.userId == widget.userId);

  @override
  void initState() {
    super.initState();
    widget.api.session.addListener(_sessionChanged);
    widget.api.profileChanges.addListener(_profileChanged);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(FeedFollowListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      oldWidget.api.session.removeListener(_sessionChanged);
      oldWidget.api.profileChanges.removeListener(_profileChanged);
      widget.api.session.addListener(_sessionChanged);
      widget.api.profileChanges.addListener(_profileChanged);
    }
    if (oldWidget.api != widget.api ||
        oldWidget.userId != widget.userId ||
        oldWidget.following != widget.following) {
      _sessionChanged();
    }
  }

  @override
  void dispose() {
    widget.api.session.removeListener(_sessionChanged);
    widget.api.profileChanges.removeListener(_profileChanged);
    super.dispose();
  }

  void _sessionChanged() {
    _pending.clear();
    _mutationErrors.clear();
    _load(reset: true);
  }

  void _profileChanged() => _load(reset: true);

  bool _current(int generation) => mounted && generation == _generation;

  String _message(Object error) => error is RunlineApiException
      ? error.message
      : '목록을 불러오지 못했어요. 다시 시도해주세요.';

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _cursor == null)) return;
    final generation = reset ? ++_generation : _generation;
    _failedReset = reset;
    setState(() {
      if (reset) {
        _users.clear();
        _removed.clear();
        _cursor = null;
      }
      _loading = widget.api.session.isSignedIn;
      _error = null;
    });
    if (!widget.api.session.isSignedIn) return;
    try {
      final kind = widget.following ? 'following' : 'followers';
      final suffix = _cursor == null
          ? ''
          : '?cursor=${Uri.encodeQueryComponent(_cursor!)}';
      final data = await widget.api.json(
        '/users/${Uri.encodeComponent(widget.userId)}/$kind$suffix',
      );
      if (!_current(generation)) return;
      setState(() {
        final ids = _users.map((user) => user['id']).toSet();
        _users.addAll(
          (data['users'] as List).cast<Map<String, dynamic>>().where(
            (user) => !_removed.contains(user['id']) && ids.add(user['id']),
          ),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (error) {
      if (_current(generation)) setState(() => _error = _message(error));
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _unfollow(String userId) async {
    if (!_canUnfollow || _pending.containsKey(userId)) return;
    final operation = Object();
    _pending[userId] = operation;
    final generation = _generation;
    final api = widget.api;
    final owner = api.session.userId;
    setState(() => _mutationErrors.remove(userId));
    try {
      await api.json(
        '/users/${Uri.encodeComponent(userId)}/follow',
        method: 'DELETE',
      );
      if (!mounted ||
          !identical(api, widget.api) ||
          !api.session.isSignedIn ||
          owner != api.session.userId) {
        return;
      }
      widget.onFollowChanged?.call();
      if (!_current(generation)) {
        await _load(reset: true);
        return;
      }
      setState(() {
        _removed.add(userId);
        _users.removeWhere((user) => user['id'] == userId);
      });
    } catch (error) {
      if (_current(generation)) {
        setState(
          () => _mutationErrors[userId] = error is RunlineApiException
              ? error.message
              : '팔로우를 취소하지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted && identical(_pending[userId], operation)) {
        setState(() => _pending.remove(userId));
      }
    }
  }

  Future<void> _openProfile(String userId) async {
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FeedProfileScreen(
          userId: userId,
          api: widget.api,
          onFollowChanged: () {
            changed = true;
            widget.onFollowChanged?.call();
          },
        ),
      ),
    );
    if (mounted && changed) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.following ? '팔로잉' : '팔로워')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.api.session.isSignedIn) const Text('로그인 후 목록을 확인해주세요.'),
          for (final user in _users)
            ListTile(
              key: ValueKey('follow-user-${user['id']}'),
              contentPadding: EdgeInsets.zero,
              leading: FeedAvatar(
                name: (user['nickname'] as String?) ?? '러너',
                avatarUrl: user['avatarUrl'] as String?,
                api: widget.api,
              ),
              title: Text(
                (user['nickname'] as String?)?.trim().isNotEmpty == true
                    ? user['nickname'] as String
                    : '러너',
              ),
              subtitle: _mutationErrors[user['id']] == null
                  ? null
                  : Text(
                      _mutationErrors[user['id']]!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              onTap: () => _openProfile(user['id'] as String),
              trailing: _canUnfollow
                  ? OutlinedButton(
                      onPressed: _pending.containsKey(user['id'])
                          ? null
                          : () => _unfollow(user['id'] as String),
                      child: Text(
                        _pending.containsKey(user['id']) ? '처리 중…' : '팔로우 취소',
                      ),
                    )
                  : null,
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            TextButton(
              onPressed: _loading ? null : () => _load(reset: _failedReset),
              child: Text('$_error 다시 시도'),
            ),
          if (!_loading &&
              _error == null &&
              _users.isEmpty &&
              _cursor == null &&
              widget.api.session.isSignedIn)
            Text(widget.following ? '아직 팔로잉한 러너가 없어요.' : '아직 팔로워가 없어요.'),
          if (!_loading && _error == null && _cursor != null)
            TextButton(onPressed: _load, child: const Text('더 보기')),
        ],
      ),
    ),
  );
}
