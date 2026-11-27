import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../../shared/media/runline_image.dart';
import 'club_ui.dart';
import 'club_files.dart';
import 'club_notice_editor_screen.dart';

class ClubNoticesScreen extends StatefulWidget {
  const ClubNoticesScreen({
    super.key,
    required this.clubId,
    required this.owner,
    this.api,
  });
  final String clubId;
  final bool owner;
  final RunlineApi? api;
  @override
  State<ClubNoticesScreen> createState() => _ClubNoticesScreenState();
}

class _ClubNoticesScreenState extends State<ClubNoticesScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  late final ClubPageController _list;
  @override
  void initState() {
    super.initState();
    _list = ClubPageController(_api, '/clubs/${widget.clubId}/notices');
    _list.load();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _detail(String id) async {
    await openClubPage(
      context,
      _api,
      ClubNoticeDetailScreen(clubId: widget.clubId, noticeId: id, api: _api),
    );
    if (mounted) await _list.load();
  }

  Future<void> _create() async {
    final id = await openClubPage<String>(
      context,
      _api,
      ClubNoticeEditorScreen(clubId: widget.clubId, api: _api),
    );
    if (id == null || !mounted) return;
    await _detail(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('공지'),
      actions: [
        if (widget.owner)
          IconButton(
            tooltip: '공지 작성',
            onPressed: _create,
            icon: const Icon(Icons.edit_square),
          ),
      ],
    ),
    body: ClubPagedList(
      controller: _list,
      emptyText: '등록된 공지가 없어요.',
      itemBuilder: (notice) => ListTile(
        leading: notice['pinned'] == true
            ? const Icon(Icons.push_pin)
            : const Icon(Icons.article_outlined),
        title: Text(notice['title'] as String),
        subtitle: Text(
          '${notice['author_nickname']} · ${clubDate(notice['created_at'])} · 첨부 ${notice['attachment_count']}개',
        ),
        onTap: () => _detail(notice['id'] as String),
      ),
    ),
  );
}

class ClubNoticeDetailScreen extends StatefulWidget {
  const ClubNoticeDetailScreen({
    super.key,
    required this.clubId,
    required this.noticeId,
    this.api,
    this.files = const ClubFiles(),
  });
  final String clubId, noticeId;
  final RunlineApi? api;
  final ClubFiles files;
  @override
  State<ClubNoticeDetailScreen> createState() => _ClubNoticeDetailScreenState();
}

class _ClubNoticeDetailScreenState extends State<ClubNoticeDetailScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  ClubMap? _notice;
  bool _owner = false, _busy = false;
  Object? _error;
  int _generation = 0;
  String get _path => '/clubs/${widget.clubId}/notices/${widget.noticeId}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _notice = null;
      _error = null;
    });
    try {
      final result = await Future.wait([
        _api.json('/clubs/${widget.clubId}/home'),
        _api.json(_path),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _notice = result[1]['notice'] as ClubMap;
        _owner = result[0]['membership']['role'] == 'owner';
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) clubMessage(context, clubError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _menu(String action) async {
    if (action == 'edit' || action == 'photos') {
      final saved = await openClubPage<String>(
        context,
        _api,
        ClubNoticeEditorScreen(
          clubId: widget.clubId,
          notice: _notice,
          attachmentsOnly: action == 'photos',
          api: _api,
        ),
      );
      if (saved != null && mounted) await _load();
    } else if (action == 'pin') {
      await _mutate(() async {
        await _api.json(
          _path,
          method: 'PATCH',
          body: {'pinned': _notice!['pinned'] != true},
        );
        if (mounted) await _load();
      });
    } else if (action == 'file') {
      await _addFile();
    } else if (action == 'delete') {
      if (!await confirmClubAction(context, '공지 삭제', '이 공지와 첨부파일을 삭제할까요?')) {
        return;
      }
      if (!mounted) return;
      await _mutate(() async {
        await _api.json(_path, method: 'DELETE');
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  Future<void> _addFile() async {
    await _mutate(() async {
      final file = await widget.files.pick();
      if (file == null || !mounted) return;
      await _api.uploadFile(
        '$_path/attachments',
        file.bytes,
        filename: file.name,
        contentType: file.contentType,
      );
      if (mounted) await _load();
    });
  }

  Future<void> _download(ClubMap file) async {
    await _mutate(() async {
      final bytes = await _api.fileBytes(
        '/api/v1$_path/attachments/${file['id']}',
      );
      if (!mounted) return;
      await widget.files.save(
        file['filename'] as String,
        file['content_type'] as String,
        bytes,
      );
    });
  }

  Future<void> _remove(ClubMap file) async {
    if (!await confirmClubAction(
      context,
      '첨부파일 삭제',
      '${file['filename']} 파일을 삭제할까요?',
    )) {
      return;
    }
    if (!mounted) return;
    await _mutate(() async {
      await _api.json('$_path/attachments/${file['id']}', method: 'DELETE');
      if (mounted) await _load();
    });
  }

  Future<void> _image(ClubMap file) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ClubSessionGate(
        api: _api,
        child: Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .65,
                child: InteractiveViewer(
                  child: RunlineImage(
                    path: file['image_url'] as String,
                    api: _api,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    final attachments = (notice?['attachments'] as List? ?? []).cast<ClubMap>();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('공지 상세'),
          actions: [
            if (_owner && notice != null)
              PopupMenuButton<String>(
                tooltip: '공지 관리',
                enabled: !_busy,
                onSelected: _menu,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('공지 수정')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(
                      notice['pinned'] == true ? '상단 고정 해제' : '상단 고정',
                    ),
                  ),
                  if (attachments.length < 5) ...[
                    const PopupMenuItem(value: 'photos', child: Text('사진 추가')),
                    const PopupMenuItem(value: 'file', child: Text('문서 첨부')),
                  ],
                  const PopupMenuItem(value: 'delete', child: Text('공지 삭제')),
                ],
              ),
          ],
        ),
        body: _error != null
            ? ClubLoadError(error: _error!, retry: _load)
            : notice == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (notice['pinned'] == true) const Text('📌 고정 공지'),
                    Text(
                      notice['title'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${notice['author_nickname']} · ${clubDate(notice['created_at'])}',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(notice['content'] as String),
                    const Divider(height: 32),
                    for (final file in attachments) ...[
                      if (file['image_url'] != null)
                        InkWell(
                          onTap: () => _image(file),
                          child: SizedBox(
                            height: 220,
                            child: RunlineImage(
                              path:
                                  file['thumbnail_url'] as String? ??
                                  file['image_url'] as String,
                              api: _api,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(file['filename'] as String),
                        subtitle: Text(
                          '${((file['size'] as num) / 1024).ceil()}KB',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '첨부파일 저장',
                              onPressed: _busy ? null : () => _download(file),
                              icon: const Icon(Icons.download_outlined),
                            ),
                            if (_owner)
                              IconButton(
                                tooltip: '첨부파일 삭제',
                                onPressed: _busy ? null : () => _remove(file),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_busy) const LinearProgressIndicator(),
                  ],
                ),
              ),
      ),
    );
  }
}
