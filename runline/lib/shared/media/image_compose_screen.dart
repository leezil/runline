import 'package:flutter/material.dart';

import 'image_optimizer.dart';
import 'image_picker_field.dart';
import 'runline_api.dart';
import 'runline_image.dart';

enum ImageComposeKind { feed }

class ImageComposeScreen extends StatefulWidget {
  const ImageComposeScreen({
    super.key,
    required this.kind,
    this.api,
    this.post,
  });

  final ImageComposeKind kind;
  final RunlineApi? api;
  final Map<String, dynamic>? post;

  @override
  State<ImageComposeScreen> createState() => _ImageComposeScreenState();
}

class _ImageComposeScreenState extends State<ImageComposeScreen> {
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  final _body = TextEditingController();
  List<OptimizedUploadImage> _images = [];
  final _mediaIds = <String>[];
  final _existingMedia = <Map<String, dynamic>>[];
  late final String? _account;
  bool _accountChanged = false;
  bool _saving = false;
  bool _preparing = false;
  String? _error;

  bool get _editing => widget.post != null;
  bool get _canEdit =>
      !_editing ||
      (_account != null && widget.post!['author']?['id'] == _account);

  @override
  void initState() {
    super.initState();
    _account = _api.session.userId;
    _body.text = widget.post?['body'] as String? ?? '';
    _existingMedia.addAll(
      ((widget.post?['media'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((media) => Map<String, dynamic>.of(media)),
    );
    _api.session.addListener(_sessionChanged);
  }

  @override
  void didUpdateWidget(ImageComposeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      (oldWidget.api ?? RunlineApi.instance).session.removeListener(
        _sessionChanged,
      );
      _api.session.addListener(_sessionChanged);
      _clearDraft();
    }
  }

  void _clearDraft() {
    _accountChanged = true;
    _body.clear();
    _images = [];
    _mediaIds.clear();
    _existingMedia.clear();
  }

  void _sessionChanged() {
    if (!_api.session.isSignedIn || _api.session.userId != _account) {
      setState(_clearDraft);
    }
  }

  bool _current(RunlineApi api) =>
      mounted &&
      identical(api, _api) &&
      !_accountChanged &&
      api.session.isSignedIn &&
      api.session.userId == _account;

  @override
  void dispose() {
    _api.session.removeListener(_sessionChanged);
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _preparing || _accountChanged || !_canEdit) return;
    final body = _body.text.trim();
    if (body.runes.length > 2000 ||
        body.contains('\u0000') ||
        (body.isEmpty && _images.isEmpty && _existingMedia.isEmpty)) {
      setState(() => _error = '내용(최대 2,000자) 또는 사진을 추가해주세요.');
      return;
    }
    if (_images.length + _existingMedia.length > 4) {
      setState(() => _error = '사진은 최대 4장까지 첨부할 수 있어요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = _api;
    try {
      if (!_current(api)) {
        throw const RunlineApiException('로그인 후 다시 시도해주세요.');
      }
      // Upload first, then atomically attach the returned IDs when saving the post.
      // Keep successful uploads when retrying a partially failed submission.
      while (_mediaIds.length < _images.length) {
        final result = await api.upload(
          '/feed/media',
          _images[_mediaIds.length],
        );
        if (!_current(api)) return;
        setState(() => _mediaIds.add(result['media']['id'] as String));
      }
      if (!_current(api)) return;
      await api.json(
        _editing
            ? '/feed/posts/${Uri.encodeComponent(widget.post!['id'] as String)}'
            : '/feed/posts',
        method: _editing ? 'PATCH' : 'POST',
        body: {
          'body': body,
          'mediaIds': [
            ..._existingMedia.map((media) => media['id'] as String),
            ..._mediaIds,
          ],
        },
      );
      if (!mounted || !_current(api)) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (_current(api)) {
        setState(
          () => _error = error is RunlineApiException
              ? error.message
              : '저장하지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving || _accountChanged,
    child: Scaffold(
      appBar: AppBar(title: Text(_editing ? '게시글 수정' : '게시글 작성')),
      body: _accountChanged || !_api.session.isSignedIn
          ? const Center(child: Text('계정이 변경되었어요. 돌아간 뒤 다시 시도해주세요.'))
          : !_canEdit
          ? const Center(child: Text('본인의 게시글만 수정할 수 있어요.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _body,
                  enabled: !_saving,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: '내용'),
                ),
                const SizedBox(height: 16),
                if (_existingMedia.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final media in _existingMedia)
                        SizedBox(
                          key: ValueKey('existing-media-${media['id']}'),
                          width: 100,
                          height: 110,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: RunlineImage(
                                    path: media['url'] as String,
                                    api: _api,
                                    thumbnail: true,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton.filledTonal(
                                  tooltip: '첨부 사진 삭제',
                                  onPressed: _saving || _preparing
                                      ? null
                                      : () => setState(
                                          () => _existingMedia.remove(media),
                                        ),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                UploadImagePicker(
                  purpose: UploadImagePurpose.feed,
                  images: _images,
                  maxImages: 4 - _existingMedia.length,
                  lockedCount: _mediaIds.length,
                  enabled: !_saving,
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _preparing = busy);
                  },
                  onChanged: (images) {
                    if (!_saving && !_accountChanged) {
                      setState(() => _images = images);
                    }
                  },
                ),
                const SizedBox(height: 20),
                if (_saving) const Center(child: CircularProgressIndicator()),
                if (_error != null) Text(_error!),
                FilledButton(
                  onPressed: _saving || _preparing ? null : _save,
                  child: const Text('저장'),
                ),
              ],
            ),
    ),
  );
}
