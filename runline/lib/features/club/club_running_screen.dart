import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../../shared/widgets/app_card.dart';
import 'club_ui.dart';
import 'club_run_editor_screen.dart';
import 'club_run_detail_screen.dart';

class ClubRunningScreen extends StatefulWidget {
  const ClubRunningScreen({super.key, required this.clubId, this.api});
  final String clubId;
  final RunlineApi? api;
  @override
  State<ClubRunningScreen> createState() => _ClubRunningScreenState();
}

class _ClubRunningScreenState extends State<ClubRunningScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  String _filter = 'recruiting';
  late final ClubPageController _list;
  @override
  void initState() {
    super.initState();
    _list = ClubPageController(_api, _path);
    _list.load();
  }

  String get _path => '/clubs/${widget.clubId}/runs?filter=$_filter';
  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await openClubPage(
      context,
      _api,
      ClubRunDetailScreen(clubId: widget.clubId, runId: id, api: _api),
    );
    if (mounted) await _list.load();
  }

  Future<void> _create() async {
    final id = await openClubPage<String>(
      context,
      _api,
      ClubRunEditorScreen(clubId: widget.clubId, api: _api),
    );
    if (!mounted || id == null) return;
    await _open(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('클럽 러닝'),
      actions: [
        IconButton(
          tooltip: '러닝 만들기',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                'recruiting': '모집 중',
                'all': '전체',
                'upcoming': '예정',
                'in_progress': '진행 중',
                'past': '지난 러닝',
                'cancelled': '취소',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() => _filter = entry.key);
                    _list.path = _path;
                    _list.load();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: ClubPagedList(
            controller: _list,
            emptyText: '해당하는 클럽 러닝이 없어요.',
            itemBuilder: (run) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () => _open(run['id'] as String),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          runStateLabel(run['state']),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (run['is_participating'] == true) const Text('참가 중'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      run['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(clubDate(run['starts_at'])),
                    Text(run['location'] as String),
                    Text(
                      '${run['participant_count']} / ${run['capacity']}명 · ${run['creator_nickname']}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
