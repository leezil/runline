import 'package:flutter/material.dart';

import '../../shared/media/club_image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_label_action.dart';
import 'club_ui.dart';
import 'club_members_screen.dart';
import 'club_notices_screen.dart';
import 'club_running_screen.dart';
import 'club_run_detail_screen.dart';
import 'club_settings_screen.dart';
import 'chat/club_chat_screen.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key, this.api});
  final RunlineApi? api;
  @override
  Widget build(BuildContext context) {
    final client = api ?? RunlineApi.instance;
    return ClubSessionGate(
      api: client,
      allowAccountSwitch: true,
      child: _ClubHome(key: ObjectKey(client), api: client),
    );
  }
}

class _ClubHome extends StatefulWidget {
  const _ClubHome({super.key, required this.api});
  final RunlineApi api;
  @override
  State<_ClubHome> createState() => _ClubHomeState();
}

class _ClubHomeState extends State<_ClubHome> {
  RunlineApi get _api => widget.api;
  late final ClubPageController _list;
  ClubMap? _club, _membership;
  String _query = '', _region = '';
  bool _loading = true, _busy = false;
  int _unread = 0, _generation = 0;
  Object? _error;
  bool _chatUnavailable = false;
  bool get _owner => _membership?['role'] == 'owner';
  @override
  void initState() {
    super.initState();
    _list = ClubPageController(_api, '/clubs/recommended');
    _api.profileChanges.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _api.profileChanges.removeListener(_load);
    _list.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await _api.json('/me/club');
      if (!mounted || generation != _generation) return;
      final club = mine['club'] as ClubMap?;
      final path = club != null
          ? '/clubs/${club['id']}/feed'
          : _query.isEmpty
          ? '/clubs/recommended'
          : '/clubs';
      final params = <String, String>{
        if (club == null && _query.isNotEmpty) 'query': _query,
        if (club == null && _region.isNotEmpty) 'region': _region,
      };
      _list.path = Uri(
        path: path,
        queryParameters: params.isEmpty ? null : params,
      ).toString();
      setState(() {
        _club = club;
        _membership = mine['membership'] as ClubMap?;
        _loading = false;
        _unread = 0;
        _chatUnavailable = false;
      });
      await Future.wait([
        _list.load(),
        if (club != null) _loadChat(club['id'] as String, generation),
      ]);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadChat(String id, int generation) async {
    try {
      final result = await _api.json('/clubs/$id/chat');
      if (mounted && generation == _generation) {
        setState(
          () => _unread = (result['state']['unread_count'] as num).toInt(),
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _chatUnavailable = true);
      }
    }
  }

  Future<void> _view(Widget screen) async {
    await openClubPage(context, _api, screen);
    if (mounted) await _load();
  }

  Future<void> _join(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.json('/clubs/$id/join', method: 'POST');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final query = TextEditingController(text: _query),
        region = TextEditingController(text: _region);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('클럽 검색'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: query,
                maxLength: 50,
                decoration: const InputDecoration(labelText: '클럽 이름'),
              ),
              TextField(
                controller: region,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '활동 지역 (선택)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, [query.text.trim(), region.text.trim()]),
            child: const Text('검색'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      query.dispose();
      region.dispose();
    });
    if (!mounted || result == null) return;
    _query = result[0];
    _region = result[1];
    await _load();
  }

  Widget _image(ClubMap club, double size) => SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: club['image_url'] == null
          ? const Icon(Icons.groups_outlined)
          : RunlineImage(
              path: club['image_url'] as String,
              thumbnail: true,
              api: _api,
            ),
    ),
  );
  Widget _entry(ClubMap item) {
    final club = _club;
    if (club == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _image(item, 48),
            title: Text(item['name'] as String),
            subtitle: Text('${item['region']} · ${item['member_count']}명'),
            onTap: _busy
                ? null
                : () => _view(
                    ClubPublicDetailScreen(
                      clubId: item['id'] as String,
                      api: _api,
                    ),
                  ),
            trailing: FilledButton(
              onPressed: _busy ? null : () => _join(item['id'] as String),
              child: const Text('가입'),
            ),
          ),
        ),
      );
    }
    final notice = item['target_type'] == 'notice';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: item['thumbnail_url'] == null
              ? Icon(notice ? Icons.campaign_outlined : Icons.directions_run)
              : SizedBox(
                  width: 48,
                  height: 48,
                  child: RunlineImage(
                    path: item['thumbnail_url'] as String,
                    api: _api,
                  ),
                ),
          title: Text(
            (item['current_notice_title'] ??
                    item['current_run_title'] ??
                    item['title'])
                as String,
          ),
          subtitle: Text(
            '${const {'notice_created': '공지', 'run_created': '러닝 모집', 'run_updated': '러닝 변경', 'run_cancelled': '러닝 취소'}[item['type']] ?? ''} · ${clubDate(item['created_at'])}',
          ),
          onTap: () => _view(
            notice
                ? ClubNoticeDetailScreen(
                    clubId: club['id'] as String,
                    noticeId: item['target_id'] as String,
                    api: _api,
                  )
                : ClubRunDetailScreen(
                    clubId: club['id'] as String,
                    runId: item['target_id'] as String,
                    api: _api,
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '클럽',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: '내 프로필 편집',
                onPressed: _busy
                    ? null
                    : () => _view(ClubProfileEditorScreen(api: _api)),
                icon: const Icon(Icons.manage_accounts_outlined),
              ),
              if (!_loading && _error == null && club == null) ...[
                IconButton(
                  tooltip: '클럽 검색',
                  onPressed: _busy ? null : _search,
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: '클럽 만들기',
                  onPressed: _busy
                      ? null
                      : () => _view(
                          ClubImageComposeScreen(
                            kind: ClubImageComposeKind.clubCreate,
                            api: _api,
                          ),
                        ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              if (!_loading && _error == null && club != null)
                IconButton(
                  tooltip: '클럽 설정',
                  onPressed: _busy
                      ? null
                      : () => _view(
                          ClubSettingsScreen(
                            clubId: club['id'] as String,
                            api: _api,
                          ),
                        ),
                  icon: const Icon(Icons.settings_outlined),
                ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ClubLoadError(error: _error!, retry: _load)
              : ClubPagedList(
                  controller: _list,
                  onRefresh: _load,
                  emptyText: club == null
                      ? '검색된 클럽이 없어요.'
                      : '아직 등록된 클럽 소식이 없어요.',
                  itemBuilder: _entry,
                  header: [
                    if (club == null) ...[
                      Text(
                        _query.isEmpty && _region.isEmpty
                            ? '클럽에 가입하고 함께 달려보세요.\n추천 클럽'
                            : '검색 결과 · $_query $_region',
                      ),
                      if (_query.isNotEmpty || _region.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _query = '';
                            _region = '';
                            _load();
                          },
                          child: const Text('추천 클럽 보기'),
                        ),
                    ] else ...[
                      AppCard(
                        child: Row(
                          children: [
                            _image(club, 64),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    club['name'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  Text(
                                    '${club['region']} · 멤버 ${club['member_count']}명',
                                  ),
                                  if ((club['description'] as String)
                                      .isNotEmpty)
                                    Text(
                                      club['description'] as String,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
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
                            onPressed: () => _view(
                              ClubNoticesScreen(
                                clubId: club['id'] as String,
                                owner: _owner,
                                api: _api,
                              ),
                            ),
                          ),
                          IconLabelAction(
                            label: '멤버',
                            icon: Icons.people_outline,
                            onPressed: () => _view(
                              ClubMembersScreen(
                                clubId: club['id'] as String,
                                membership: _membership!,
                                api: _api,
                              ),
                            ),
                          ),
                          IconLabelAction(
                            label: '클럽 러닝',
                            icon: Icons.directions_run,
                            onPressed: () => _view(
                              ClubRunningScreen(
                                clubId: club['id'] as String,
                                api: _api,
                              ),
                            ),
                          ),
                          Badge.count(
                            count: _unread,
                            isLabelVisible: _unread > 0,
                            child: IconLabelAction(
                              label: '채팅',
                              icon: Icons.chat_bubble_outline,
                              onPressed: () => _view(
                                ClubChatScreen(
                                  clubId: club['id'] as String,
                                  clubName: club['name'] as String,
                                  api: _api,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_chatUnavailable)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '채팅 미확인 수를 불러오지 못했어요. 채팅에서 다시 연결할 수 있어요.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '클럽 소식',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class ClubPublicDetailScreen extends StatefulWidget {
  const ClubPublicDetailScreen({super.key, required this.clubId, this.api});
  final String clubId;
  final RunlineApi? api;
  @override
  State<ClubPublicDetailScreen> createState() => _ClubPublicDetailScreenState();
}

class _ClubPublicDetailScreenState extends State<ClubPublicDetailScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  late Future<ClubMap> _club;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _club = _api.json('/clubs/${widget.clubId}');
  }

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.json('/clubs/${widget.clubId}/join', method: 'POST');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('클럽 소개')),
    body: FutureBuilder<ClubMap>(
      future: _club,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ClubLoadError(
            error: snapshot.error!,
            retry: () =>
                setState(() => _club = _api.json('/clubs/${widget.clubId}')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final club = snapshot.data!['club'] as ClubMap;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (club['image_url'] != null)
              SizedBox(
                height: 220,
                child: RunlineImage(
                  path: club['image_url'] as String,
                  api: _api,
                  fit: BoxFit.contain,
                ),
              ),
            Text(
              club['name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${club['region']} · ${club['member_count']}명'),
            const SizedBox(height: 16),
            Text(club['description'] as String),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text(_busy ? '가입 중…' : '즉시 가입'),
            ),
          ],
        );
      },
    ),
  );
}
