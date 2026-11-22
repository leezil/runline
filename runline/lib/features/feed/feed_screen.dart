import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/media/image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import '../../shared/widgets/app_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _posts = <Map<String, dynamic>>[];
  String? _cursor;
  String? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    RunlineSession.instance.addListener(_sessionChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    RunlineSession.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && _cursor == null) return;
    final generation = reset ? ++_generation : _generation;
    if (reset) {
      _posts.clear();
      _cursor = null;
    }
    if (!RunlineSession.instance.isSignedIn) {
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
      final data = await RunlineApi.instance.json('/feed/posts$suffix');
      if (!mounted || generation != _generation) return;
      setState(() {
        final existing = _posts.map((post) => post['id']).toSet();
        _posts.addAll(
          (data['items'] as List).cast<Map<String, dynamic>>().where(
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
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ImageComposeScreen(kind: ImageComposeKind.feed),
                    ),
                  );
                  if (saved == true && mounted) await _load(reset: true);
                },
                icon: const Icon(Icons.edit_square),
                tooltip: '게시글 작성',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('러너들의 새로운 활동을 확인하세요.', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          if (!RunlineSession.instance.isSignedIn)
            const Text('로그인하면 러너들의 사진과 게시글을 볼 수 있어요.'),
          if (_error != null)
            TextButton(
              onPressed: () => _load(reset: _posts.isEmpty),
              child: Text('$_error 다시 시도'),
            ),
          if (!_loading &&
              _error == null &&
              _posts.isEmpty &&
              RunlineSession.instance.isSignedIn)
            const Text('첫 러닝 소식을 남겨보세요.'),
          for (final post in _posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['nickname'] as String,
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(post['title'] as String, style: textTheme.titleMedium),
                    if ((post['content'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(post['content'] as String),
                      ),
                    if ((post['images'] as List).isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: (post['images'] as List).length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image =
                                post['images'][index] as Map<String, dynamic>;
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
          if (!_loading && _cursor != null)
            TextButton(onPressed: _load, child: const Text('더 보기')),
        ],
      ),
    );
  }
}
