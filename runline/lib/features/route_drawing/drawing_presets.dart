import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Ordered outlines in a unit square. Only the closing point repeats; there
/// are no pen lifts, synthetic road coordinates, or API-specific shape fields.
enum DrawingPreset {
  star('별'),
  heart('하트'),
  crescent('초승달');

  const DrawingPreset(this.label);
  final String label;

  List<Offset> get normalizedPoints {
    final points = switch (this) {
      star => [
        for (var i = 0; i < 10; i++)
          Offset(
            .5 +
                (i.isEven ? .46 : .20) *
                    math.cos(-math.pi / 2 + i * math.pi / 5),
            .5 +
                (i.isEven ? .46 : .20) *
                    math.sin(-math.pi / 2 + i * math.pi / 5),
          ),
      ],
      heart => [for (var i = 0; i < 96; i++) _heartPoint(i * 2 * math.pi / 96)],
      crescent => _crescentPoints(),
    };
    final distinct = <Offset>[];
    for (final point in points) {
      if (distinct.isEmpty || (point - distinct.last).distance > 1e-9) {
        distinct.add(point);
      }
    }
    // Exact closure is intentional: the server receives a continuous outline.
    if ((distinct.last - distinct.first).distance > 1e-9) {
      distinct.add(distinct.first);
    } else {
      distinct[distinct.length - 1] = distinct.first;
    }
    return List.unmodifiable(distinct);
  }

  /// Uniform scale and centering preserve the shape on tall/wide canvases.
  List<Offset> pointsFor(Size canvasSize) {
    if (!canvasSize.isFinite || canvasSize.isEmpty) {
      throw ArgumentError.value(
        canvasSize,
        'canvasSize',
        'Must be finite and positive',
      );
    }
    final side = canvasSize.shortestSide * .85;
    final origin = Offset(
      (canvasSize.width - side) / 2,
      (canvasSize.height - side) / 2,
    );
    return List.unmodifiable(normalizedPoints.map((p) => origin + p * side));
  }
}

Offset _heartPoint(double t) => Offset(
  .5 + 16 * math.pow(math.sin(t), 3) / 36,
  .43 -
      (13 * math.cos(t) -
              5 * math.cos(2 * t) -
              2 * math.cos(3 * t) -
              math.cos(4 * t)) /
          36,
);

List<Offset> _crescentPoints() {
  // Intersect two circles. Trace the outer left arc down, then the inner
  // concave arc back up, sharing their tips without an artificial bridge.
  const outerRadius = 1.0, innerRadius = .9, separation = .5;
  const intersectionX =
      (outerRadius * outerRadius -
          innerRadius * innerRadius +
          separation * separation) /
      (2 * separation);
  final intersectionY = math.sqrt(1 - intersectionX * intersectionX);
  final outerAngle = math.acos(intersectionX);
  final innerAngle = math.atan2(intersectionY, intersectionX - separation);
  Offset normalized(double x, double y) =>
      Offset(.5 + .45 * (x + (1 - intersectionX) / 2), .5 + .45 * y);
  return [
    for (var i = 0; i <= 64; i++)
      normalized(
        math.cos(-outerAngle - (2 * math.pi - 2 * outerAngle) * i / 64),
        math.sin(-outerAngle - (2 * math.pi - 2 * outerAngle) * i / 64),
      ),
    for (var i = 1; i < 48; i++)
      normalized(
        separation +
            innerRadius *
                math.cos(innerAngle + (2 * math.pi - 2 * innerAngle) * i / 48),
        innerRadius *
            math.sin(innerAngle + (2 * math.pi - 2 * innerAngle) * i / 48),
      ),
  ];
}
