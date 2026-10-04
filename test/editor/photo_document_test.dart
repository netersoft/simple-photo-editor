import 'dart:math' as math;
import 'dart:ui';

import 'package:filmkit/filmkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/editor/layers.dart';
import 'package:simple_photo_editor/core/editor/photo_document.dart';

void main() {
  const stroke = StrokeLayer(points: [Offset(0.1, 0.2), Offset(0.4, 0.8)], color: Color(0xFFFF0000), width: 0.01);
  const item = ItemLayer(kind: ItemKind.text, content: 'Hi', center: Offset(0.3, 0.2), rotation: 0.5);
  const doc = PhotoDocument(basePath: 'base.jpg', layers: [stroke, item]);

  group('rotated', () {
    test('turns the photo a quarter clockwise and moves the layers with it', () {
      final rotated = doc.rotated();
      expect(rotated.quarterTurns, 1);
      // (x, y) → (1 - y, x): the top left corner goes to the top right.
      final points = (rotated.layers[0] as StrokeLayer).points;
      expect(points[0].dx, closeTo(0.8, 1e-9));
      expect(points[0].dy, closeTo(0.1, 1e-9));
      expect(points[1].dx, closeTo(0.2, 1e-9));
      expect(points[1].dy, closeTo(0.4, 1e-9));
      final turnedItem = rotated.layers[1] as ItemLayer;
      expect(turnedItem.center.dx, closeTo(0.8, 1e-9));
      expect(turnedItem.center.dy, closeTo(0.3, 1e-9));
      expect(turnedItem.rotation, closeTo(0.5 + math.pi / 2, 1e-9));
    });

    test('four turns bring everything back', () {
      final back = doc.rotated().rotated().rotated().rotated();
      expect(back.quarterTurns, 0);
      final points = (back.layers[0] as StrokeLayer).points;
      expect(points[0].dx, closeTo(0.1, 1e-9));
      expect(points[0].dy, closeTo(0.2, 1e-9));
    });

    test('turns the other way once mirrored, since the mirror applies after the turns', () {
      expect(doc.mirrored().rotated().quarterTurns, 3);
      expect(doc.mirrored().rotated().flipped, isTrue);
    });
  });

  test('mirrored flips positions and rotations horizontally', () {
    final mirrored = doc.mirrored();
    expect(mirrored.flipped, isTrue);
    expect((mirrored.layers[0] as StrokeLayer).points.first.dx, closeTo(0.9, 1e-9));
    final mirroredItem = mirrored.layers[1] as ItemLayer;
    expect(mirroredItem.center.dx, closeTo(0.7, 1e-9));
    expect(mirroredItem.rotation, -0.5);
    expect(doc.mirrored().mirrored().flipped, isFalse);
  });

  group('cropChanged', () {
    test('a missing state is the original, uncropped photo', () {
      expect(cropChanged(null, const EditorState(aspect: CropAspect.original)), isFalse);
      expect(cropChanged(null, const EditorState(look: 'Sepia')), isFalse);
    });

    test('detects a new ratio, zoom or position', () {
      expect(cropChanged(null, const EditorState(aspect: CropAspect.square)), isTrue);
      expect(cropChanged(const EditorState(), const EditorState(cropZoom: 2)), isTrue);
      expect(cropChanged(const EditorState(), const EditorState(cropCenter: Offset(0.4, 0.5))), isTrue);
    });
  });
}
