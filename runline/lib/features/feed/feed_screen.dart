import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/media/image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import '../../shared/widgets/app_card.dart';
import 'feed_profile_screen.dart';
import 'feed_post_screen.dart';
import 'widgets/feed_avatar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.api});

  final RunlineApi? api;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _posts = <Map<String, dynamic>>[];
  String _timeline = 'recommended';
  String? _cursor;
  String? _error;
  bool _loading = false;
  int _generation = 0;
  bool _failedReset = true;
  RunlineApi get _api => widget.api ?? RunlineApi.instance;

  @override
  void initState() {
    super.initState();
    _api.session.addListener(_sessionChanged);
    _api.profileChanges.addListener(_sessionChanged);
    _api.postsChanges.addListener(_sessionChanged);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      (oldWidget.api ?? RunlineApi.instance).session.removeListener(
        _sessionChanged,
      );
      (oldWidget.api ?? RunlineApi.instance).profileChanges.removeListener(
        _sessionChanged,
      );
      (oldWidget.api ?? RunlineApi.instance).postsChanges.removeListener(
        _sessionChanged,
      );
      _api.session.addListener(_sessionChanged);
      _api.profileChanges.addListener(_sessionChanged);
      _api.postsChanges.addListener(_sessionChanged);
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _api.session.removeListener(_sessionChanged);
    _api.profileChanges.removeListener(_sessionChanged);
    _api.postsChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && _cursor == null) return;
    _failedReset = reset;
    final generation = reset ? ++_generation : _generation;
    if (reset) {
      _posts.clear();
      _cursor = null;
    }
    if (!_api.session.isSignedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final suffix = _cursor == null
          ? ''
          : '?cursor=${Uri.encodeQueryComponent(_cursor!)}';
      final data = await _api.json('/feed/$_timeline$suffix');
      if (!mounted || generation != _generation) return;
      setState(() {
        final existing = _posts.map((post) => post['id']).toSet();
        _posts.addAll(
          (data['posts'] as List).cast<Map<String, dynamic>>().where(
            (post) => !existing.contains(post['id']),
          ),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is RunlineApiException
              ? error.message
              : '피드를 불러오지 못했어요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProfile([String? userId]) async {
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FeedProfileScreen(
          userId: userId,
          api: _api,
          onFollowChanged: () => changed = true,
        ),
      ),
    );
    if (mounted && changed) await _load(reset: true);
  }

  Future<void> _openPost(String postId) async {
    var changed = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FeedPostScreen(
          postId: postId,
          api: _api,
          onFollowChanged: () => changed = true,
        ),
      ),
    );
    if (mounted && changed) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Text('피드', style: textTheme.headlineMedium)),
              IconButton(
                onPressed: _api.session.isSignedIn
                    ? () => _openProfile()
                    : null,
                icon: const Icon(Icons.account_circle_outlined),
                tooltip: '내 프로필',
              ),
              IconButton(
                onPressed: !_api.session.isSignedIn
                    ? null
                    : () async {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ImageComposeScreen(
                              kind: ImageComposeKind.feed,
                              api: _api,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.edit_square),
                tooltip: '게시글 작성',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('러너들의 새로운 활동을 확인하세요.', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final entry in {
                'recommended': '추천',
                'following': '팔로잉',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _timeline == entry.key,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() => _timeline = entry.key);
                      _load(reset: true);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_api.session.isSignedIn)
            const Text('로그인하면 러너들의 사진과 게시글을 볼 수 있어요.'),
          if (_error != null)
            TextButton(
              onPressed: _loading ? null : () => _load(reset: _failedReset),
              child: Text('$_error 다시 시도'),
            ),
          if (!_loading &&
              _error == null &&
              _posts.isEmpty &&
              _api.session.isSignedIn)
            const Text('첫 러닝 소식을 남겨보세요.'),
          for (final post in _posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: FeedAvatar(
                        name: post['author']['nickname'] as String? ?? '러너',
                        avatarUrl: post['author']['avatarUrl'] as String?,
                        api: _api,
                      ),
                      title: Text(
                        (post['author']['nickname'] as String?)
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? post['author']['nickname'] as String
                            : '러너',
                        style: textTheme.labelLarge,
                      ),
                      onTap: post['author']['id'] is String
                          ? () => _openProfile(post['author']['id'] as String)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    if ((post['body'] as String? ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _openPost(post['id'] as String),
                          child: Text(post['body'] as String),
                        ),
                      ),
                    if ((post['media'] as List).isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: (post['media'] as List).length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image =
                                post['media'][index] as Map<String, dynamic>;
                            return SizedBox(
                              width: 240,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(),
                                      body: InteractiveViewer(
                                        child: Center(
                                          child: RunlineImage(
                                            path: image['url'] as String,
                                            api: _api,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: RunlineImage(
                                    path: image['url'] as String,
                                    api: _api,
                                    thumbnail: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _error == null && _cursor != null)
            TextButton(onPressed: _load, child: const Text('더 보기')),
        ],
      ),
    );
  }
}
