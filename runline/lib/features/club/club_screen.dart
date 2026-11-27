import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_label_action.dart';
import '../../shared/media/club_image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import 'club_notices_screen.dart';
import 'chat/club_chat_screen.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});
  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  Map<String, dynamic>? _club;
  bool _owner = false;
  int _unreadChat = 0;
  List<Map<String, dynamic>> _items = [];
  String? _cursor;
  String _query = '';
  String? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    RunlineApi.instance.session.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    RunlineApi.instance.session.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading && more) return;
    final generation = more ? _generation : ++_generation;
    if (!more) {
      _club = null;
      _items = [];
      _cursor = null;
      _owner = false;
      _unreadChat = 0;
    }
    if (!RunlineApi.instance.session.isSignedIn) {
      if (mounted) {
        setState(() {
          _error = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!more) {
        final mine = await RunlineApi.instance.json('/me/club');
        if (!mounted || generation != _generation) return;
        _club = mine['club'] as Map<String, dynamic>?;
        _owner = mine['membership']?['role'] == 'owner';
        if (_club != null) {
          final chat = await RunlineApi.instance.json(
            '/clubs/${_club!['id']}/chat',
          );
          if (!mounted || generation != _generation) return;
          _unreadChat = chat['state']['unread_count'] as int;
        }
      }
      final params = <String, String>{
        if (more && _cursor != null) 'cursor': _cursor!,
        if (_club == null && _query.isNotEmpty) 'query': _query,
      };
      final path = _club != null
          ? '/clubs/${_club!['id']}/feed'
          : _query.isEmpty
          ? '/clubs/recommended'
          : '/clubs';
      final result = await RunlineApi.instance.json(
        '$path${params.isEmpty ? '' : '?${Uri(queryParameters: params).query}'}',
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll((result['items'] as List).cast<Map<String, dynamic>>());
        _cursor = result['nextCursor'] as String?;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is RunlineApiException
              ? error.message
              : '클럽을 불러오지 못했어요.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _search() async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('클럽 검색'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          decoration: const InputDecoration(labelText: '클럽 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('검색'),
          ),
        ],
      ),
    );
    // The dialog's exit animation may still use the controller; dispose on a later frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null && mounted) {
      _query = result;
      await _load();
    }
  }

  Future<void> _join(String clubId) async {
    setState(() => _loading = true);
    try {
      await RunlineApi.instance.json('/clubs/$clubId/join', method: 'POST');
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is RunlineApiException ? error.message : '가입하지 못했어요.';
        });
      }
    }
  }

  Future<void> _collection(String suffix, String title) async {
    try {
      final data = await RunlineApi.instance.json(
        '/clubs/${_club!['id']}/$suffix',
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            children: [
              ListTile(title: Text(title)),
              for (final item in data['items'] as List)
                ListTile(
                  title: Text((item['nickname'] ?? item['title']) as String),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '클럽',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            if (!_loading && _club == null) ...[
              IconButton(
                tooltip: '클럽 검색',
                onPressed: _search,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: '클럽 만들기',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const ClubImageComposeScreen(
                        kind: ClubImageComposeKind.clubCreate,
                      ),
                    ),
                  );
                  if (saved == true && mounted) await _load();
                },
              ),
            ],
            if (_owner && _club != null)
              IconButton(
                tooltip: '클럽 사진 변경',
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: () async {
                  await openClubImageComposer(
                    context,
                    ClubImageComposeKind.clubCover,
                  );
                  if (mounted) await _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!RunlineApi.instance.session.isSignedIn)
          const Text('로그인 후 클럽을 찾아보세요.'),
        if (RunlineApi.instance.session.isSignedIn &&
            _club == null &&
            !_loading)
          Text(
            _query.isEmpty ? '클럽에 가입하고 함께 달려보세요.\n추천 클럽' : '“$_query” 검색 결과',
          ),
        if (_club != null) ...[
          AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _club!['image_url'] == null
                        ? const Icon(Icons.groups, size: 40)
                        : RunlineImage(
                            path: _club!['image_url'] as String,
                            thumbnail: true,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _club!['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '멤버 ${_club!['member_count']}명 · ${_club!['region']}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconLabelAction(
                label: '공지',
                icon: Icons.campaign_outlined,
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ClubNoticesScreen(
                        clubId: _club!['id'] as String,
                        owner: _owner,
                      ),
                    ),
                  );
                  if (mounted) await _load();
                },
              ),
              IconLabelAction(
                label: '멤버',
                icon: Icons.people_outline,
                onPressed: () => _collection('members', '멤버'),
              ),
              IconLabelAction(
                label: '클럽 러닝',
                icon: Icons.directions_run,
                onPressed: () => _collection('runs', '클럽 러닝'),
              ),
              Badge.count(
                count: _unreadChat,
                isLabelVisible: _unreadChat > 0,
                child: IconLabelAction(
                  label: '채팅',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ClubChatScreen(
                          clubId: _club!['id'] as String,
                          clubName: _club!['name'] as String,
                        ),
                      ),
                    );
                    if (mounted) await _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: _club == null
                  ? ListTile(
                      leading: item['image_url'] == null
                          ? const Icon(Icons.groups)
                          : SizedBox(
                              width: 52,
                              height: 52,
                              child: RunlineImage(
                                path: item['image_url'] as String,
                                thumbnail: true,
                              ),
                            ),
                      title: Text(item['name'] as String),
                      subtitle: Text(
                        '${item['region']} · ${item['member_count']}명',
                      ),
                      trailing: FilledButton(
                        onPressed: _loading
                            ? null
                            : () => _join(item['id'] as String),
                        child: const Text('가입'),
                      ),
                    )
                  : ListTile(
                      title: Text(
                        (item['current_notice_title'] ??
                                item['current_run_title'] ??
                                item['title'])
                            as String,
                      ),
                      leading: item['thumbnail_url'] == null
                          ? null
                          : SizedBox(
                              width: 52,
                              height: 52,
                              child: RunlineImage(
                                path: item['thumbnail_url'] as String,
                              ),
                            ),
                      onTap: item['target_type'] != 'notice'
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ClubNoticeDetailScreen(
                                  clubId: _club!['id'] as String,
                                  noticeId: item['target_id'] as String,
                                ),
                              ),
                            ),
                    ),
            ),
          ),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error 다시 시도')),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _cursor != null)
          TextButton(
            onPressed: () => _load(more: true),
            child: const Text('더 보기'),
          ),
      ],
    ),
  );
}
