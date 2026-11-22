import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_optimizer.dart';

class UploadImagePicker extends StatefulWidget {
  const UploadImagePicker({
    super.key,
    required this.purpose,
    required this.images,
    required this.onChanged,
    this.maxImages = 5,
    this.enabled = true,
    this.onBusyChanged,
    this.lockedCount = 0,
  });
  final UploadImagePurpose purpose;
  final List<OptimizedUploadImage> images;
  final ValueChanged<List<OptimizedUploadImage>> onChanged;
  final int maxImages;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  final int lockedCount;
  @override
  State<UploadImagePicker> createState() => _UploadImagePickerState();
}

class _UploadImagePickerState extends State<UploadImagePicker> {
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) {
        return;
      }
      if (await file.length() > UploadImageOptimizer.maxSourceBytes) {
        throw const ImageOptimizationException('20MB 이하의 사진을 선택해주세요.');
      }
      final optimized = await UploadImageOptimizer().optimize(
        await file.readAsBytes(),
        widget.purpose,
      );
      if (!mounted) return;
      widget.onChanged([...widget.images, optimized]);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ImageOptimizationException
              ? error.message
              : '사진을 선택하지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < widget.images.length; i++)
            SizedBox(
              width: 100,
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        widget.images[i].bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton.filledTonal(
                      tooltip: '사진 삭제',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: !widget.enabled || _busy || i < widget.lockedCount
                          ? null
                          : () {
                              final images = [...widget.images]..removeAt(i);
                              widget.onChanged(images);
                            },
                    ),
                  ),
                ],
              ),
            ),
          if (widget.images.length < widget.maxImages)
            SizedBox(
              width: 100,
              height: 110,
              child: OutlinedButton(
                onPressed: !widget.enabled || _busy ? null : _pick,
                child: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined),
                          Text('사진 추가'),
                        ],
                      ),
              ),
            ),
        ],
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('사진을 준비하고 있어요…'),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
