import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// What the user draws or places over the photo. Positions are normalized to the
/// edited image (0..1 on each axis); sizes are relative to its shortest side, so the
/// layers render the same on screen and at full resolution.
@immutable
sealed class Layer {
  const Layer();

  /// The layer after the whole image is turned a quarter clockwise.
  Layer rotatedQuarter();

  /// The layer after the whole image is mirrored horizontally.
  Layer flippedHorizontally();
}

/// A brush or eraser stroke. The eraser only erases strokes, not the photo.
class StrokeLayer extends Layer {
  const StrokeLayer({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
  });

  final List<Offset> points;
  final Color color;

  /// Stroke width, relative to the image's shortest side.
  final double width;
  final bool eraser;

  StrokeLayer withPoint(Offset point) => StrokeLayer(points: [...points, point], color: color, width: width, eraser: eraser);

  StrokeLayer _mapPoints(Offset Function(Offset) f) => StrokeLayer(points: points.map(f).toList(), color: color, width: width, eraser: eraser);

  @override
  StrokeLayer rotatedQuarter() => _mapPoints(_rotateQuarter);

  @override
  StrokeLayer flippedHorizontally() => _mapPoints(_flip);
}

enum ItemKind { text, emoji, sticker }

/// A text, emoji or sticker that can be moved, scaled and rotated.
class ItemLayer extends Layer {
  const ItemLayer({
    required this.kind,
    required this.content,
    this.color = const Color(0xFFFFFFFF),
    this.center = const Offset(0.5, 0.5),
    this.scale = 1,
    this.rotation = 0,
  });

  final ItemKind kind;

  /// The text, the emoji, or the sticker's asset path.
  final String content;

  /// Text color.
  final Color color;
  final Offset center;

  /// Size factor: 1 is the default size of the kind (see `ItemMetrics`).
  final double scale;

  /// Clockwise, in radians.
  final double rotation;

  ItemLayer copyWith({String? content, Color? color, Offset? center, double? scale, double? rotation}) => ItemLayer(
    kind: kind,
    content: content ?? this.content,
    color: color ?? this.color,
    center: center ?? this.center,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );

  @override
  ItemLayer rotatedQuarter() => copyWith(center: _rotateQuarter(center), rotation: rotation + math.pi / 2);

  @override
  ItemLayer flippedHorizontally() => copyWith(center: _flip(center), rotation: -rotation);
}

Offset _rotateQuarter(Offset p) => Offset(1 - p.dy, p.dx);

Offset _flip(Offset p) => Offset(1 - p.dx, p.dy);
