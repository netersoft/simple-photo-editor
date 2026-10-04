import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/editor/layers.dart';
import 'package:simple_photo_editor/core/editor/layers_painter.dart';

void main() {
  const metrics = ItemMetrics(Size(1000, 500), {});

  test('items scale with the shortest side of the canvas', () {
    const item = ItemLayer(kind: ItemKind.sticker, content: 'missing.png');
    // Without its image, a sticker is a square of 30 % of the shortest side.
    expect(metrics.sizeOf(item), const Size.square(150));
    expect(metrics.sizeOf(item.copyWith(scale: 2)), const Size.square(300));
  });

  test('hits follow the item rotation', () {
    const item = ItemLayer(kind: ItemKind.sticker, content: 'missing.png');
    // A 150 px square at the center, (500, 250).
    expect(metrics.hits(item, const Offset(560, 250), margin: 0), isTrue);
    expect(metrics.hits(item, const Offset(600, 250), margin: 0), isFalse);
    expect(metrics.hits(item, const Offset(600, 250), margin: 30), isTrue);

    // Turned 45°, its corner reaches √2 × 75 ≈ 106 px from the center along the axes.
    final turned = item.copyWith(rotation: math.pi / 4);
    expect(metrics.hits(turned, const Offset(600, 250), margin: 0), isTrue);
    expect(metrics.hits(turned, const Offset(570, 180), margin: 0), isFalse);
  });
}
