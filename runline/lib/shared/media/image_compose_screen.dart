import 'package:flutter/material.dart';

import 'image_optimizer.dart';
import 'image_picker_field.dart';
import 'runline_api.dart';

enum ImageComposeKind { feed, clubCreate, notice, avatar, clubCover }

class ImageComposeScreen extends StatefulWidget {
  const ImageComposeScreen({
    super.key,
    required this.kind,
    this.clubId,
    this.api,
  });
  final ImageComposeKind kind;
  final String? clubId;
  final RunlineApi? api;
  @override
  State<ImageComposeScreen> createState() => _ImageComposeScreenState();
}

class _ImageComposeScreenState extends State<ImageComposeScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _region = TextEditingController();
  List<OptimizedUploadImage> _images = [];
  String? _createdId;
  int _uploaded = 0;
  bool _saving = false;
  bool _preparing = false;
  String? _error;
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  bool get _imageOnly =>
      widget.kind == ImageComposeKind.avatar ||
      widget.kind == ImageComposeKind.clubCover;
  UploadImagePurpose get _purpose => switch (widget.kind) {
    ImageComposeKind.avatar => UploadImagePurpose.avatar,
    ImageComposeKind.clubCreate ||
    ImageComposeKind.clubCover => UploadImagePurpose.clubCover,
    ImageComposeKind.notice => UploadImagePurpose.clubNotice,
    ImageComposeKind.feed => UploadImagePurpose.feed,
  };
  String get _label => switch (widget.kind) {
    ImageComposeKind.feed => '게시글 작성',
    ImageComposeKind.clubCreate => '클럽 만들기',
    ImageComposeKind.notice => '공지 작성',
    ImageComposeKind.avatar => '프로필 사진 변경',
    ImageComposeKind.clubCover => '클럽 사진 변경',
  };
  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_imageOnly && _images.isEmpty) {
      setState(() => _error = '사진을 선택해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!_api.session.isSignedIn) {
        throw const RunlineApiException('로그인 후 이용해주세요.');
      }
      if (_createdId == null && !_imageOnly) {
        final result = await switch (widget.kind) {
          ImageComposeKind.feed => _api.json(
            '/feed/posts',
            method: 'POST',
            body: {
              'title': _title.text.trim(),
              'content': _content.text.trim(),
            },
          ),
          ImageComposeKind.clubCreate => _api.json(
            '/clubs',
            method: 'POST',
            body: {
              'name': _title.text.trim(),
              'region': _region.text.trim(),
              'description': _content.text.trim(),
            },
          ),
          ImageComposeKind.notice => _api.json(
            '/clubs/${widget.clubId}/notices',
            method: 'POST',
            body: {
              'title': _title.text.trim(),
              'content': _content.text.trim(),
            },
          ),
          _ => throw StateError('Invalid composer'),
        };
        final key = switch (widget.kind) {
          ImageComposeKind.feed => 'post',
          ImageComposeKind.clubCreate => 'club',
          _ => 'notice',
        };
        _createdId = (result[key] as Map<String, dynamic>)['id'] as String;
      }
      final endpoint = switch (widget.kind) {
        ImageComposeKind.feed => '/feed/posts/$_createdId/images',
        ImageComposeKind.clubCreate => '/clubs/$_createdId/image',
        ImageComposeKind.notice =>
          '/clubs/${widget.clubId}/notices/$_createdId/attachments',
        ImageComposeKind.avatar => '/me/avatar',
        ImageComposeKind.clubCover => '/clubs/${widget.clubId}/image',
      };
      while (_uploaded < _images.length) {
        await _api.upload(endpoint, _images[_uploaded]);
        if (!mounted) return;
        setState(() => _uploaded++);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
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
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_label)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_imageOnly) ...[
              TextFormField(
                controller: _title,
                enabled: !_saving && _createdId == null,
                maxLength: widget.kind == ImageComposeKind.clubCreate
                    ? 50
                    : 100,
                decoration: InputDecoration(
                  labelText: widget.kind == ImageComposeKind.clubCreate
                      ? '클럽 이름'
                      : '제목',
                ),
                validator: (value) =>
                    value?.trim().isNotEmpty == true ? null : '입력해주세요.',
              ),
              if (widget.kind == ImageComposeKind.clubCreate)
                TextFormField(
                  controller: _region,
                  enabled: !_saving && _createdId == null,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '활동 지역'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : '활동 지역을 입력해주세요.',
                ),
              TextFormField(
                controller: _content,
                enabled: !_saving && _createdId == null,
                maxLines: 5,
                maxLength: widget.kind == ImageComposeKind.clubCreate
                    ? 2000
                    : 10000,
                decoration: const InputDecoration(labelText: '내용'),
                validator: (value) =>
                    widget.kind == ImageComposeKind.notice &&
                        value?.trim().isNotEmpty != true
                    ? '내용을 입력해주세요.'
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            UploadImagePicker(
              purpose: _purpose,
              images: _images,
              maxImages:
                  _purpose == UploadImagePurpose.avatar ||
                      _purpose == UploadImagePurpose.clubCover
                  ? 1
                  : 5,
                enabled: !_saving,
                lockedCount: _uploaded,
              onBusyChanged: (busy) {
                if (mounted) setState(() => _preparing = busy);
              },
              onChanged: (images) => setState(() => _images = images),
            ),
            const SizedBox(height: 20),
            if (_saving)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('저장 중… $_uploaded / ${_images.length}'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving || _preparing ? null : _save,
              child: Text(_createdId == null ? '저장' : '다시 시도'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> openClubImageComposer(
  BuildContext context,
  ImageComposeKind kind, {
  RunlineApi? api,
}) async {
  final client = api ?? RunlineApi.instance;
  try {
    final mine = await client.json('/me/club');
    if (mine['club'] == null) throw const RunlineApiException('클럽에 먼저 가입해주세요.');
    if (mine['membership']?['role'] != 'owner') {
      throw const RunlineApiException('클럽장만 사용할 수 있어요.');
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImageComposeScreen(
          kind: kind,
          clubId: mine['club']['id'] as String,
          api: client,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is RunlineApiException ? error.message : '클럽 정보를 불러오지 못했어요.',
          ),
        ),
      );
    }
  }
}
