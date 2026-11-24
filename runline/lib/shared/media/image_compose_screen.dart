import 'package:flutter/material.dart';

import 'image_optimizer.dart';
import 'image_picker_field.dart';
import 'runline_api.dart';

enum ImageComposeKind { feed }

class ImageComposeScreen extends StatefulWidget {
  const ImageComposeScreen({super.key, required this.kind, this.api});

  final ImageComposeKind kind;
  final RunlineApi? api;

  @override
  State<ImageComposeScreen> createState() => _ImageComposeScreenState();
}

class _ImageComposeScreenState extends State<ImageComposeScreen> {
  final _body = TextEditingController();
  List<OptimizedUploadImage> _images = [];
  final _mediaIds = <String>[];
  bool _saving = false;
  bool _preparing = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _preparing) return;
    final body = _body.text.trim();
    if (body.runes.length > 2000 || (body.isEmpty && _images.isEmpty)) {
      setState(() => _error = '내용(최대 2,000자) 또는 사진을 추가해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = widget.api ?? RunlineApi.instance;
    try {
      // Upload first, then atomically attach the returned IDs when creating the post.
      // Keep successful uploads when retrying a partially failed submission.
      while (_mediaIds.length < _images.length) {
        final result = await api.upload(
          '/feed/media',
          _images[_mediaIds.length],
        );
        if (!mounted) return;
        setState(() => _mediaIds.add(result['media']['id'] as String));
      }
      await api.json(
        '/feed/posts',
        method: 'POST',
        body: {'body': body, 'mediaIds': _mediaIds},
      );
      if (mounted) Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('게시글 작성')),
      body: ListView(
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
          UploadImagePicker(
            purpose: UploadImagePurpose.feed,
            images: _images,
            maxImages: 4,
            lockedCount: _mediaIds.length,
            enabled: !_saving,
            onBusyChanged: (busy) {
              if (mounted) setState(() => _preparing = busy);
            },
            onChanged: (images) => setState(() => _images = images),
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
