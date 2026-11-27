import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import 'feed_profile_screen.dart';
import 'widgets/feed_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    widget.api.session.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(FeedPostScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      oldWidget.api.session.removeListener(_load);
      widget.api.session.addListener(_load);
    }
    if (oldWidget.api != widget.api || oldWidget.postId != widget.postId) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.api.session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
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

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      appBar: AppBar(title: const Text('게시물')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
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
                onTap: () => Navigator.of(context).push<void>(
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
    );
  }
}
