import 'package:flutter/material.dart';

import '../../shared/media/image_compose_screen.dart';
import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';

class ClubNoticesScreen extends StatefulWidget {
  const ClubNoticesScreen({
    super.key,
    required this.clubId,
    required this.owner,
  });
  final String clubId;
  final bool owner;
  @override
  State<ClubNoticesScreen> createState() => _ClubNoticesScreenState();
}

class _ClubNoticesScreenState extends State<ClubNoticesScreen> {
  late Future<Map<String, dynamic>> _notices;
  @override
  void initState() {
    super.initState();
    _load();
    RunlineSession.instance.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(_load); }

  @override
  void dispose() { RunlineSession.instance.removeListener(_refresh); super.dispose(); }

  void _load() {
    _notices = RunlineApi.instance.json('/clubs/${widget.clubId}/notices');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('공지'),
      actions: [
        if (widget.owner)
          IconButton(
            tooltip: '공지 작성',
            icon: const Icon(Icons.edit_square),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ImageComposeScreen(
                    kind: ImageComposeKind.notice,
                    clubId: widget.clubId,
                  ),
                ),
              );
              if (saved == true && mounted) setState(_load);
            },
          ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
        key: ValueKey(_notices),
      future: _notices,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: const Text('공지를 불러오지 못했어요. 다시 시도'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!['items'] as List;
        if (items.isEmpty) return const Center(child: Text('등록된 공지가 없어요.'));
        return ListView(
          children: [
            for (final item in items)
              ListTile(
                leading: item['pinned'] == true
                    ? const Icon(Icons.push_pin)
                    : null,
                title: Text(item['title'] as String),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ClubNoticeDetailScreen(
                      clubId: widget.clubId,
                      noticeId: item['id'] as String,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class ClubNoticeDetailScreen extends StatefulWidget {
  const ClubNoticeDetailScreen({
    super.key,
    required this.clubId,
    required this.noticeId,
  });
  final String clubId;
  final String noticeId;
  @override
  State<ClubNoticeDetailScreen> createState() => _ClubNoticeDetailScreenState();
}

class _ClubNoticeDetailScreenState extends State<ClubNoticeDetailScreen> {
  late Future<Map<String, dynamic>> _notice;
  @override
  void initState() {
    super.initState();
    _load();
    RunlineSession.instance.addListener(_refresh);
  }

  void _load() {
    _notice = RunlineApi.instance.json(
      '/clubs/${widget.clubId}/notices/${widget.noticeId}',
    );
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    RunlineSession.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('공지')),
    body: FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_notice),
      future: _notice,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('공지를 불러오지 못했어요. 다시 시도'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notice = snapshot.data!['notice'] as Map<String, dynamic>;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              notice['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(notice['content'] as String),
            for (final file in notice['attachments'] as List)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: file['image_url'] == null
                    ? Text(file['filename'] as String)
                    : SizedBox(
                        height: 360,
                        child: InteractiveViewer(
                          child: RunlineImage(
                            path: file['image_url'] as String,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
              ),
          ],
        );
      },
    ),
  );
}
