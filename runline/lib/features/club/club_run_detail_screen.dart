import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../feed/widgets/feed_avatar.dart';
import 'club_ui.dart';
import 'club_run_editor_screen.dart';

class ClubRunDetailScreen extends StatefulWidget {
  const ClubRunDetailScreen({
    super.key,
    required this.clubId,
    required this.runId,
    this.api,
  });
  final String clubId, runId;
  final RunlineApi? api;
  @override
  State<ClubRunDetailScreen> createState() => _ClubRunDetailScreenState();
}

class _ClubRunDetailScreenState extends State<ClubRunDetailScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  late final ClubPageController _participants;
  ClubMap? _run, _membership;
  Object? _error;
  bool _busy = false;
  int _generation = 0;
  String get _path => '/clubs/${widget.clubId}/runs/${widget.runId}';
  @override
  void initState() {
    super.initState();
    _participants = ClubPageController(_api, '$_path/participants');
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _participants.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _run = null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.json('/clubs/${widget.clubId}/home'),
        _api.json(_path),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _membership = results[0]['membership'] as ClubMap;
        _run = results[1]['run'] as ClubMap;
      });
      await _participants.load();
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  Future<void> _action(String action) async {
    if (_busy) return;
    if (action == 'cancel' || action == 'leave') {
      final cancel = action == 'cancel';
      final confirmed = await confirmClubAction(
        context,
        cancel ? '러닝 취소' : '참가 취소',
        cancel ? '이 러닝을 취소할까요? 모든 참가가 취소됩니다.' : '이 러닝의 참가를 취소할까요?',
      );
      if (!mounted || !confirmed) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _api.json(
        action == 'cancel'
            ? '$_path/cancel'
            : action == 'leave'
            ? '$_path/participants/me'
            : '$_path/participants',
        method: action == 'leave' ? 'DELETE' : 'POST',
      );
      if (mounted) await _load();
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await openClubPage<String>(
      context,
      _api,
      ClubRunEditorScreen(clubId: widget.clubId, run: _run, api: _api),
    );
    if (saved != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final creator =
        run != null && run['creator_membership_id'] == _membership?['id'];
    final editable =
        run != null && ['recruiting', 'closed'].contains(run['state']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('클럽 러닝 상세'),
        actions: [
          if (creator && editable)
            IconButton(
              tooltip: '러닝 수정',
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _error != null
          ? ClubLoadError(error: _error!, retry: _load)
          : run == null
          ? const Center(child: CircularProgressIndicator())
          : ClubPagedList(
              controller: _participants,
              onRefresh: _load,
              emptyText: '참가자가 없어요.',
              header: [
                Text(
                  runStateLabel(run['state']),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  run['title'] as String,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('모임 장소: ${run['location']}'),
                Text('시작: ${clubDate(run['starts_at'])}'),
                Text('종료: ${clubDate(run['ends_at'])}'),
                Text('모집 마감: ${clubDate(run['registration_closes_at'])}'),
                Text('생성자: ${run['creator_nickname']}'),
                const SizedBox(height: 16),
                Text(run['description'] as String),
                const SizedBox(height: 16),
                if (creator && editable)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _action('cancel'),
                    child: const Text('러닝 취소'),
                  ),
                if (!creator && run['is_participating'] == true && editable)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _action('leave'),
                    child: const Text('참가 취소'),
                  ),
                if (run['is_participating'] != true &&
                    run['state'] == 'recruiting')
                  FilledButton(
                    onPressed: _busy ? null : () => _action('join'),
                    child: const Text('참가하기'),
                  ),
                if (_busy) const LinearProgressIndicator(),
                const Divider(height: 32),
                Text(
                  '참가자 ${run['participant_count']} / ${run['capacity']}명',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              itemBuilder: (person) => ListTile(
                leading: FeedAvatar(
                  name: person['nickname'] as String,
                  avatarUrl: person['avatar_url'] as String?,
                  api: _api,
                ),
                title: Text(person['nickname'] as String),
                subtitle: person['id'] == run['creator_membership_id']
                    ? const Text('생성자')
                    : null,
              ),
            ),
    );
  }
}
