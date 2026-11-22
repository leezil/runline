import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'runline_api.dart';

/// Fetch bytes with Bearer authentication on mobile AND web. Image.network
/// headers are not supported by Flutter's web image element path.
class RunlineImage extends StatefulWidget {
  const RunlineImage({
    super.key,
    required this.path,
    this.thumbnail = false,
    this.fit = BoxFit.cover,
    this.api,
  });
  final String path;
  final bool thumbnail;
  final BoxFit fit;
  final RunlineApi? api;
  @override
  State<RunlineImage> createState() => _RunlineImageState();
}

class _RunlineImageState extends State<RunlineImage> {
  late Future<Uint8List> _bytes;
  int _generation = 0;
  RunlineApi get _api => widget.api ?? RunlineApi.instance;
  @override
  void initState() {
    super.initState();
    _load();
    _api.session.addListener(_refresh);
  }

  void _load() {
    _generation++;
    _bytes = _api.imageBytes(widget.path, thumbnail: widget.thumbnail);
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void didUpdateWidget(RunlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      (oldWidget.api ?? RunlineApi.instance).session.removeListener(_refresh);
      _api.session.addListener(_refresh);
    }
    if (oldWidget.path != widget.path ||
        oldWidget.thumbnail != widget.thumbnail ||
        oldWidget.api != widget.api) {
      _load();
    }
  }

  @override
  void dispose() {
    _api.session.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    key: ValueKey(_generation),
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return Image.memory(
        snapshot.data!,
        fit: widget.fit,
        gaplessPlayback: false,
      );
    },
  );
}
