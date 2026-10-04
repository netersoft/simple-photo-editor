import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/editor/layers.dart';
import '../../../../core/editor/layers_painter.dart';
import '../../../../core/providers/editor/photo_editor_provider.dart';

/// The photo with its layers, fitted in the available space. Draws strokes in brush and
/// eraser modes; otherwise selects, moves, scales and turns texts, emojis and stickers.
class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({required this.onEditText, super.key});

  /// Called on a double tap on a text, with its index in the layers.
  final void Function(int index, ItemLayer item) onEditText;

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  // The item being moved, and its state and the focal point when the gesture started.
  int? _moving;
  ItemLayer? _start;
  Offset _startFocal = Offset.zero;
  bool _drawing = false;

  PhotoEditor get _editor => ref.read(photoEditorProvider.notifier);

  int? _itemAt(Offset point, Size size, PhotoEditorState state) {
    final layers = state.document!.layers;
    final metrics = ItemMetrics(size, state.stickers);
    for (var i = layers.length - 1; i >= 0; i--) {
      if (layers[i] case final ItemLayer item when metrics.hits(item, point)) return i;
    }
    return null;
  }

  Offset _normalize(Offset point, Size size) => Offset((point.dx / size.width).clamp(0, 1), (point.dy / size.height).clamp(0, 1));

  void _onScaleStart(ScaleStartDetails details, Size size) {
    final state = ref.read(photoEditorProvider);
    if (state.drawMode != DrawMode.none) {
      if (details.pointerCount > 1) return;
      _drawing = true;
      _editor.startStroke(_normalize(details.localFocalPoint, size));
      return;
    }
    final index = _itemAt(details.localFocalPoint, size, state) ?? (state.selected != null && details.pointerCount > 1 ? state.selected : null);
    _editor.select(index);
    _moving = index;
    _start = index == null ? null : state.document!.layers[index] as ItemLayer;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    if (_drawing) {
      _editor.extendStroke(_normalize(details.localFocalPoint, size));
      return;
    }
    final start = _start;
    if (_moving == null || start == null) return;
    final delta = details.localFocalPoint - _startFocal;
    _editor.updateItem(
      _moving!,
      start.copyWith(
        center: start.center + Offset(delta.dx / size.width, delta.dy / size.height),
        scale: (start.scale * details.scale).clamp(0.2, 8),
        rotation: start.rotation + details.rotation,
      ),
    );
  }

  void _onScaleEnd() {
    if (_drawing || _moving != null) _editor.commit();
    _drawing = false;
    _moving = null;
    _start = null;
  }

  void _onDoubleTap(Offset point, Size size) {
    final state = ref.read(photoEditorProvider);
    if (state.drawMode != DrawMode.none) return;
    final index = _itemAt(point, size, state);
    if (index == null) return;
    final item = state.document!.layers[index] as ItemLayer;
    if (item.kind == ItemKind.text) widget.onEditText(index, item);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoEditorProvider);
    final doc = state.document;
    final image = state.image;
    if (doc == null || image == null) return const SizedBox.shrink();

    final turned = doc.quarterTurns.isOdd;
    final aspect = turned ? image.height / image.width : image.width / image.height;
    Offset? doubleTapPoint;

    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (d) => _onScaleStart(d, size),
              onScaleUpdate: (d) => _onScaleUpdate(d, size),
              onScaleEnd: (_) => _onScaleEnd(),
              onDoubleTapDown: (d) => doubleTapPoint = d.localPosition,
              onDoubleTap: () {
                if (doubleTapPoint != null) _onDoubleTap(doubleTapPoint!, size);
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: LayersPainter(
                    image: image,
                    quarterTurns: doc.quarterTurns,
                    flipped: doc.flipped,
                    layers: doc.layers,
                    stickers: state.stickers,
                    selected: state.selectedItem,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
