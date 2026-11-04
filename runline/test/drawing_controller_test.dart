import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/route_drawing/drawing_controller.dart';

void main() {
  test('ordered samples and separate strokes produce immutable snapshots', () {
    final drawing = DrawingController();
    addTearDown(drawing.dispose);
    const size = Size(300, 400);
    drawing.beginStroke(const Offset(10, 20), size);
    drawing.addPoint(const Offset(10.5, 20), size);
    drawing.addPoint(const Offset(30, 40), size);
    drawing.endStroke();
    drawing.addPoint(const Offset(100, 100), size);
    drawing.beginStroke(const Offset(200, 200), size);
    drawing.endStroke();
    final data = drawing.snapshot()!;
    expect(data.strokes, [
      [const Offset(10, 20), const Offset(30, 40)],
      [const Offset(200, 200)],
    ]);
    expect(data.points.length, 3);
    expect(() => data.strokes.first.add(Offset.zero), throwsUnsupportedError);
    expect(() => data.strokes.clear(), throwsUnsupportedError);
    expect(() => drawing.strokes.first.clear(), throwsUnsupportedError);
    drawing.clear();
    expect(drawing.hasDrawing, isFalse);
    expect(drawing.strokes, isEmpty);
    expect(drawing.snapshot(), isNull);
    expect(data.points.length, 3);
    drawing.beginStroke(const Offset(5, 5), const Size(100, 100));
    expect(drawing.canvasSize, const Size(100, 100));
  });

  test(
    'resize keeps one coordinate space and outside input stays in bounds',
    () {
      final drawing = DrawingController();
      addTearDown(drawing.dispose);
      drawing.beginStroke(const Offset(20, 30), const Size(100, 100));
      drawing.addPoint(const Offset(100, 100), const Size(200, 200));
      drawing.addPoint(const Offset(300, -5), const Size(200, 200));
      expect(drawing.snapshot()!.points, [
        const Offset(20, 30),
        const Offset(50, 50),
        const Offset(100, 0),
      ]);
      expect(drawing.canvasSize, const Size(100, 100));
    },
  );
}
