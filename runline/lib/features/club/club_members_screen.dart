import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../feed/feed_profile_screen.dart';
import '../feed/widgets/feed_avatar.dart';
import 'club_ui.dart';

class ClubMembersScreen extends StatefulWidget {
  const ClubMembersScreen({
    super.key,
    required this.clubId,
    required this.membership,
    this.api,
  });
  final String clubId;
  final ClubMap membership;
  final RunlineApi? api;
  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  late final ClubPageController _list;
  final _search = TextEditingController();
  bool _busy = false;
  bool get _owner => widget.membership['role'] == 'owner';
  @override
  void initState() {
    super.initState();
    _list = ClubPageController(_api, '/clubs/${widget.clubId}/members');
    _list.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _list.dispose();
    super.dispose();
  }

  void _find() {
    _list.path = Uri(
      path: '/clubs/${widget.clubId}/members',
      queryParameters: {'query': _search.text.trim()},
    ).toString();
    _list.load();
  }

  Future<void> _manage(ClubMap member, String action) async {
    if (_busy) return;
    final transfer = action == 'transfer';
    final title = transfer ? '클럽장 위임' : '멤버 강퇴';
    final name = member['nickname'] as String;
    if (!await confirmClubAction(
      context,
      title,
      transfer
          ? '$name님에게 클럽장을 위임할까요? 위임 후에는 일반 멤버가 됩니다.'
          : '$name님을 강퇴할까요? 해당 멤버의 예정된 러닝과 참가도 취소됩니다.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (transfer) {
        await _api.json(
          '/clubs/${widget.clubId}/ownership',
          method: 'POST',
          body: {'membershipId': member['id']},
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        await _api.json(
          '/clubs/${widget.clubId}/members/${member['id']}',
          method: 'DELETE',
        );
        if (!mounted) return;
        await _list.load();
      }
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('멤버')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            maxLength: 30,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '닉네임 검색',
              suffixIcon: IconButton(
                tooltip: '멤버 검색',
                onPressed: _busy ? null : _find,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _find(),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: ClubPagedList(
            controller: _list,
            emptyText: '검색된 멤버가 없어요.',
            itemBuilder: (member) => ListTile(
              leading: FeedAvatar(
                name: member['nickname'] as String,
                avatarUrl: member['avatar_url'] as String?,
                api: _api,
              ),
              title: Text(
                member['nickname'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(member['role'] == 'owner' ? '클럽장' : '멤버'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedProfileScreen(
                    userId: member['user_id'] as String,
                    api: _api,
                  ),
                ),
              ),
              trailing: _owner && member['id'] != widget.membership['id']
                  ? PopupMenuButton<String>(
                      enabled: !_busy,
                      tooltip: '멤버 관리',
                      onSelected: (action) => _manage(member, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'transfer', child: Text('클럽장 위임')),
                        PopupMenuItem(value: 'kick', child: Text('강퇴')),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ],
    ),
  );
}
