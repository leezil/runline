import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import 'feed_post_screen.dart';
import 'widgets/feed_avatar.dart';

class FeedProfileScreen extends StatefulWidget {
  const FeedProfileScreen({
    super.key,
    this.userId,
    this.api,
    this.onFollowChanged,
  });

  /// Omit userId to open the signed-in user's profile.
  final String? userId;
  final RunlineApi? api;
  final VoidCallback? onFollowChanged;

  @override
  State<FeedProfileScreen> createState() => _FeedProfileScreenState();
}

class _FeedProfileScreenState extends State<FeedProfileScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  Map<String, dynamic>? _profile;
  bool _ownProfile = false;
  bool _loading = false;
  bool _loadingPosts = false;
  bool _changingFollow = false;
  String? _error;
  String? _postsError;
  String? _followError;
  String? _cursor;
  final _posts = <Map<String, dynamic>>[];
  int _generation = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _api.session.addListener(_sessionChanged);
    _load();
  }

  @override
  void didUpdateWidget(FeedProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      (oldWidget.api ?? RunlineApi.instance).session.removeListener(
        _sessionChanged,
      );
      _api.session.addListener(_sessionChanged);
    }
    if (oldWidget.api != widget.api || oldWidget.userId != widget.userId) {
      _changingFollow = false;
      _load();
    }
  }

  @override
  void dispose() {
    _api.session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    _changingFollow = false;
    _load();
  }

  bool _current(int generation) => mounted && generation == _generation;
  String _message(Object error) => error is RunlineApiException
      ? error.message
      : '정보를 불러오지 못했어요. 다시 시도해주세요.';

  Future<void> _load() async {
    if (_changingFollow) return;
    final generation = ++_generation;
    setState(() {
      _profile = null;
      _posts.clear();
      _cursor = null;
      _ownProfile = false;
      _loading = _api.session.isSignedIn;
      _loadingPosts = false;
      _changingFollow = false;
      _error = _postsError = _followError = null;
    });
    if (!_api.session.isSignedIn) return;
    try {
      // /me also provides the current user's ID, so self-follow is never offered.
      final me = (await _api.json('/me'))['profile'] as Map<String, dynamic>;
      if (!_current(generation)) return;
      final own = widget.userId == null || me['id'] == widget.userId;
      final profile = own
          ? me
          : (await _api.json(
                  '/users/${Uri.encodeComponent(widget.userId!)}',
                ))['profile']
                as Map<String, dynamic>;
      if (!_current(generation)) return;
      setState(() {
        _ownProfile = own;
        _profile = profile;
        _loading = false;
      });
      if (own) await _loadPosts(generation: generation);
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _error = _message(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadPosts({int? generation, bool more = false}) async {
    final requestGeneration = generation ?? _generation;
    if (_loadingPosts || !_ownProfile || (more && _cursor == null)) return;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    try {
      final suffix = more
          ? '?cursor=${Uri.encodeQueryComponent(_cursor!)}'
          : '';
      final data = await _api.json('/me/posts$suffix');
      if (!_current(requestGeneration)) return;
      setState(() {
        final ids = _posts.map((post) => post['id']).toSet();
        _posts.addAll(
          (data['posts'] as List).cast<Map<String, dynamic>>().where(
            (post) => ids.add(post['id']),
          ),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (error) {
      if (_current(requestGeneration)) {
        setState(() => _postsError = _message(error));
      }
    } finally {
      if (_current(requestGeneration)) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _ownProfile || _changingFollow) return;
    final generation = _generation;
    final api = _api;
    final wasFollowing = _profile!['isFollowing'] == true;
    final path = '/users/${Uri.encodeComponent(_profile!['id'] as String)}';
    var saved = false;
    setState(() {
      _changingFollow = true;
      _followError = null;
    });
    try {
      final result = await api.json(
        '$path/follow',
        method: wasFollowing ? 'DELETE' : 'PUT',
      );
      if (!mounted) return;
      widget.onFollowChanged?.call();
      if (!_current(generation)) {
        // A token refresh can notify listeners while this mutation is in flight.
        // Fetch the current viewer's data; never apply an old account's response.
        if (identical(api, _api)) await _load();
        return;
      }
      saved = true;
      setState(
        () => _profile = {
          ..._profile!,
          'isFollowing': result['isFollowing'] == true,
        },
      );
      // Refresh counts from the server instead of guessing locally.
      final data = await _api.json(path);
      if (_current(generation)) {
        setState(() => _profile = data['profile'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (_current(generation)) {
        setState(
          () => _followError = saved
              ? '팔로우 상태는 저장됐지만 정보를 갱신하지 못했어요. 아래로 당겨 새로고침해주세요.'
              : _message(error),
        );
      }
    } finally {
      if (_current(generation)) setState(() => _changingFollow = false);
    }
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FeedPostScreen(
          postId: post['id'] as String,
          api: _api,
          onFollowChanged: widget.onFollowChanged,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = (profile?['nickname'] as String?)?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(_ownProfile || widget.userId == null ? '내 프로필' : '프로필'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_api.session.isSignedIn)
                      const Text('로그인 후 프로필을 확인해주세요.'),
                    if (_loading) const CircularProgressIndicator(),
                    if (_error != null)
                      TextButton(
                        onPressed: _load,
                        child: Text('$_error 다시 시도'),
                      ),
                    if (profile != null) ...[
                      FeedAvatar(
                        name: name == null || name.isEmpty ? '러너' : name,
                        avatarUrl: profile['avatarUrl'] as String?,
                        api: _api,
                        radius: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name == null || name.isEmpty ? '러너' : name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if ((profile['bio'] as String? ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(profile['bio'] as String),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text('팔로워 ${profile['followerCount']}'),
                          Text('팔로잉 ${profile['followingCount']}'),
                        ],
                      ),
                      if (!_ownProfile) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _changingFollow ? null : _toggleFollow,
                          child: Text(
                            _changingFollow
                                ? '처리 중…'
                                : profile['isFollowing'] == true
                                ? '언팔로우'
                                : '팔로우',
                          ),
                        ),
                        if (_followError != null)
                          Text(
                            _followError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _selectedTab = 0),
                            tooltip: '게시물',
                            icon: Icon(
                              Icons.grid_view_outlined,
                              color: _selectedTab == 0
                                  ? AppColors.primary
                                  : AppColors.text,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _selectedTab = 1),
                            tooltip: '루트',
                            icon: Icon(
                              Icons.map_outlined,
                              color: _selectedTab == 1
                                  ? AppColors.primary
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (profile != null && _selectedTab == 1)
              const SliverToBoxAdapter(
                child: Center(child: Text('프로필 루트 보기는 준비 중이에요.')),
              ),
            if (profile != null && _selectedTab == 0) ...[
              if (!_ownProfile)
                const SliverToBoxAdapter(
                  child: Center(child: Text('이 사용자의 게시물 보기는 준비 중이에요.')),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final post = _posts[index];
                      final media = post['media'] as List;
                      return Material(
                        color: const Color(0xFFF5F6FA),
                        child: InkWell(
                          key: ValueKey('profile-post-${post['id']}'),
                          onTap: () => _openPost(post),
                          child: media.isNotEmpty
                              ? RunlineImage(
                                  path: media.first['url'] as String,
                                  api: _api,
                                  thumbnail: true,
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    post['body'] as String,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                      );
                    }, childCount: _posts.length),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_loadingPosts) const CircularProgressIndicator(),
                        if (_postsError != null)
                          TextButton(
                            onPressed: () =>
                                _loadPosts(more: _posts.isNotEmpty),
                            child: Text('$_postsError 다시 시도'),
                          ),
                        if (!_loadingPosts &&
                            _postsError == null &&
                            _posts.isEmpty)
                          const Text('아직 작성한 게시물이 없어요.'),
                        if (!_loadingPosts &&
                            _postsError == null &&
                            _cursor != null)
                          TextButton(
                            onPressed: () => _loadPosts(more: true),
                            child: const Text('더 보기'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
