import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Immutable canvas coordinates for a later route-generation step. Separate
/// strokes preserve pen lifts; points are never latitude/longitude values.
class DrawingData {
  DrawingData({
    required this.canvasSize,
    required Iterable<Iterable<Offset>> strokes,
  }) : strokes = List.unmodifiable(strokes.map(List<Offset>.unmodifiable));

  final Size canvasSize;
  final List<List<Offset>> strokes;

  List<Offset> get points =>
      List.unmodifiable(strokes.expand((stroke) => stroke));
}

class DrawingController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _canvasSize = Size.zero;
  bool _drawing = false;

  bool get hasDrawing => _strokes.isNotEmpty;
  Size get canvasSize => _canvasSize;
  Iterable<List<Offset>> get strokes =>
      _strokes.map((stroke) => UnmodifiableListView(stroke));

  // Keep the coordinate space of the first stroke. Resizing the browser scales
  // the drawing and maps new pointer input back into that same coordinate space.
  Offset _point(Offset local, Size viewport) => Offset(
    local.dx.clamp(0, viewport.width) * _canvasSize.width / viewport.width,
    local.dy.clamp(0, viewport.height) * _canvasSize.height / viewport.height,
  );

  bool _valid(Size size) => size.isFinite && !size.isEmpty;

  void beginStroke(Offset local, Size viewport) {
    if (!_valid(viewport)) return;
    if (!hasDrawing) _canvasSize = viewport;
    _strokes.add([_point(local, viewport)]);
    _drawing = true;
    notifyListeners();
  }

  void addPoint(Offset local, Size viewport) {
    if (!_drawing || !_valid(viewport)) return;
    final point = _point(local, viewport);
    if ((point - _strokes.last.last).distance < 2) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void endStroke() => _drawing = false;

  void clear() {
    if (!hasDrawing) return;
    _drawing = false;
    _strokes.clear();
    _canvasSize = Size.zero;
    notifyListeners();
  }

  DrawingData? snapshot() => hasDrawing
      ? DrawingData(canvasSize: canvasSize, strokes: _strokes)
      : null;
}
