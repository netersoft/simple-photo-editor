import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'layers.dart';

/// Sizes of the items on a canvas, shared by the painter and the hit tests.
class ItemMetrics {
  const ItemMetrics(this.canvasSize, this.stickers);

  final Size canvasSize;

  /// Decoded sticker images, by asset path.
  final Map<String, ui.Image> stickers;

  double get _unit => canvasSize.shortestSide;

  Offset centerOf(ItemLayer item) => Offset(item.center.dx * canvasSize.width, item.center.dy * canvasSize.height);

  TextPainter textPainter(ItemLayer item) {
    final emoji = item.kind == ItemKind.emoji;
    return TextPainter(
      text: TextSpan(
        text: item.content,
        style: TextStyle(
          fontSize: (emoji ? 0.16 : 0.1) * _unit * item.scale,
          color: emoji ? null : item.color,
          fontWeight: FontWeight.w600,
          height: 1.15,
          shadows: emoji ? null : [Shadow(color: Colors.black54, blurRadius: 0.01 * _unit * item.scale)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// The unrotated size of [item].
  Size sizeOf(ItemLayer item) {
    if (item.kind == ItemKind.sticker) {
      final image = stickers[item.content];
      final width = 0.3 * _unit * item.scale;
      if (image == null) return Size.square(width);
      return Size(width, width * image.height / image.width);
    }
    return textPainter(item).size;
  }

  /// Whether [point] (canvas coordinates) falls on [item], with some margin for fingers.
  bool hits(ItemLayer item, Offset point, {double margin = 12}) {
    final local = _rotate(point - centerOf(item), -item.rotation);
    final size = sizeOf(item);
    return local.dx.abs() <= size.width / 2 + margin && local.dy.abs() <= size.height / 2 + margin;
  }

  static Offset _rotate(Offset p, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }
}

/// Paints the photo (turned [quarterTurns] times clockwise, then mirrored if [flipped])
/// and the layers over it, filling the canvas.
class LayersPainter extends CustomPainter {
  LayersPainter({
    required this.layers,
    required this.stickers,
    this.image,
    this.quarterTurns = 0,
    this.flipped = false,
    this.selected,
  });

  final ui.Image? image;
  final int quarterTurns;
  final bool flipped;
  final List<Layer> layers;
  final Map<String, ui.Image> stickers;

  /// The item drawn with a selection frame.
  final ItemLayer? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (image case final image?) paintImage(canvas, size, image, quarterTurns, flipped);

    final metrics = ItemMetrics(size, stickers);
    final strokes = layers.whereType<StrokeLayer>().toList();

    // Strokes go on their own layer, so that the eraser only clears them.
    if (strokes.isNotEmpty) {
      canvas.saveLayer(Offset.zero & size, Paint());
      for (final stroke in strokes) {
        _paintStroke(canvas, size, stroke);
      }
      canvas.restore();
    }

    for (final item in layers.whereType<ItemLayer>()) {
      _paintItem(canvas, metrics, item);
    }
  }

  static void paintImage(Canvas canvas, Size size, ui.Image image, int quarterTurns, bool flipped) {
    final turned = quarterTurns.isOdd;
    final drawn = turned ? Size(size.height, size.width) : size;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(flipped ? -1 : 1, 1)
      ..rotate(quarterTurns * math.pi / 2)
      ..drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: drawn.width, height: drawn.height),
        Paint()..filterQuality = FilterQuality.high,
      )
      ..restore();
  }

  void _paintStroke(Canvas canvas, Size size, StrokeLayer stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.eraser ? BlendMode.dstOut : BlendMode.srcOver;
    final points = stroke.points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
    if (points.length == 1) {
      canvas.drawPoints(ui.PointMode.points, points, paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      // Quadratic curves through the midpoints, for smooth lines.
      final mid = Offset.lerp(points[i - 1], points[i], 0.5)!;
      path.quadraticBezierTo(points[i - 1].dx, points[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintItem(Canvas canvas, ItemMetrics metrics, ItemLayer item) {
    final itemSize = metrics.sizeOf(item);
    canvas
      ..save()
      ..translate(metrics.centerOf(item).dx, metrics.centerOf(item).dy)
      ..rotate(item.rotation);
    final topLeft = Offset(-itemSize.width / 2, -itemSize.height / 2);

    if (item.kind == ItemKind.sticker) {
      final image = stickers[item.content];
      if (image != null) {
        canvas.drawImageRect(
          image,
          Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
          topLeft & itemSize,
          Paint()..filterQuality = FilterQuality.high,
        );
      }
    } else {
      metrics.textPainter(item).paint(canvas, topLeft);
    }

    if (identical(item, selected)) {
      final frame = (topLeft & itemSize).inflate(6);
      canvas
        ..drawRect(
          frame,
          Paint()
            ..color = Colors.black38
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        )
        ..drawRect(
          frame,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LayersPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.quarterTurns != quarterTurns ||
      oldDelegate.flipped != flipped ||
      oldDelegate.layers != layers ||
      oldDelegate.stickers != stickers ||
      oldDelegate.selected != selected;
}
