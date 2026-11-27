import 'package:flutter/material.dart';

import '../../shared/media/runline_api.dart';
import '../../shared/media/image_optimizer.dart';
import '../../shared/media/image_picker_field.dart';
import 'club_ui.dart';

class ClubNoticeEditorScreen extends StatefulWidget {
  const ClubNoticeEditorScreen({
    super.key,
    required this.clubId,
    this.notice,
    this.attachmentsOnly = false,
    this.api,
  }) : assert(!attachmentsOnly || notice != null);
  final String clubId;
  final ClubMap? notice;
  final bool attachmentsOnly;
  final RunlineApi? api;
  @override
  State<ClubNoticeEditorScreen> createState() => _ClubNoticeEditorScreenState();
}

class _ClubNoticeEditorScreenState extends State<ClubNoticeEditorScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _content;
  late bool _pinned;
  String? _savedId;
  bool _textSaved = false, _saving = false, _preparing = false;
  List<OptimizedUploadImage> _images = [];
  int _uploaded = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.notice?['title'] as String? ?? '',
    );
    _content = TextEditingController(
      text: widget.notice?['content'] as String? ?? '',
    );
    _pinned = widget.notice?['pinned'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _preparing || !_form.currentState!.validate()) return;
    if (widget.attachmentsOnly && _images.isEmpty) {
      setState(() => _error = '추가할 사진을 선택해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!_textSaved && !widget.attachmentsOnly) {
        final editing = widget.notice != null;
        final result = await _api.json(
          '/clubs/${widget.clubId}/notices${editing ? '/${widget.notice!['id']}' : ''}',
          method: editing ? 'PATCH' : 'POST',
          body: {
            'title': _title.text.trim(),
            'content': _content.text.trim(),
            'pinned': _pinned,
          },
        );
        if (!mounted) return;
        setState(() {
          _savedId = result['notice']['id'] as String;
          _textSaved = true;
        });
      }
      final id = _savedId ?? widget.notice!['id'] as String;
      while (_uploaded < _images.length) {
        await _api.upload(
          '/clubs/${widget.clubId}/notices/$id/attachments',
          _images[_uploaded],
        );
        if (!mounted) return;
        setState(() => _uploaded++);
      }
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) setState(() => _error = clubError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = (widget.notice?['attachments'] as List? ?? []).length;
    final available = (5 - count).clamp(0, 5);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.attachmentsOnly
                ? '공지 사진 추가'
                : widget.notice == null
                ? '공지 작성'
                : '공지 수정',
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!widget.attachmentsOnly) ...[
                TextFormField(
                  controller: _title,
                  enabled: !_saving && !_textSaved,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '공지 제목'),
                  validator: (value) =>
                      value?.trim().isNotEmpty == true ? null : '제목을 입력해주세요.',
                ),
                TextFormField(
                  controller: _content,
                  enabled: !_saving && !_textSaved,
                  maxLength: 10000,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '공지 내용'),
                  validator: (value) =>
                      value?.trim().isNotEmpty == true ? null : '내용을 입력해주세요.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('상단 고정'),
                  value: _pinned,
                  onChanged: _saving || _textSaved
                      ? null
                      : (value) => setState(() => _pinned = value),
                ),
              ],
              Text('사진·문서를 합쳐 최대 5개까지 첨부할 수 있어요. 현재 첨부: $count개'),
              const SizedBox(height: 12),
              if (available > 0)
                UploadImagePicker(
                  purpose: UploadImagePurpose.clubNotice,
                  images: _images,
                  maxImages: available,
                  lockedCount: _uploaded,
                  enabled: !_saving,
                  onChanged: (images) => setState(() => _images = images),
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _preparing = busy);
                  },
                ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_textSaved)
                const Text('공지 본문은 저장됐어요. 사진 업로드 실패 시 다시 시도할 수 있어요.'),
              FilledButton(
                onPressed: _saving || _preparing ? null : _save,
                child: Text(
                  _saving
                      ? '저장 중… $_uploaded / ${_images.length}'
                      : _textSaved
                      ? '사진 업로드 다시 시도'
                      : '저장',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
