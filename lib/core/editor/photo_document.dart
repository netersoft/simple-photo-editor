import 'package:filmkit/filmkit.dart';
import 'package:flutter/foundation.dart';

import 'layers.dart';

/// One state of the edited photo, as kept in the undo history.
@immutable
class PhotoDocument {
  const PhotoDocument({
    required this.basePath,
    this.filmState,
    this.quarterTurns = 0,
    this.flipped = false,
    this.layers = const [],
  });

  /// The photo with filmkit's edits (crop, filter, adjustments) applied, as a JPEG.
  final String basePath;

  /// filmkit's editor state, to reopen it where the user left off.
  final EditorState? filmState;

  /// Clockwise quarter turns of the base photo, applied before [flipped].
  final int quarterTurns;

  /// Whether the turned photo is mirrored horizontally.
  final bool flipped;
  final List<Layer> layers;

  PhotoDocument copyWith({String? basePath, EditorState? filmState, int? quarterTurns, bool? flipped, List<Layer>? layers}) => PhotoDocument(
    basePath: basePath ?? this.basePath,
    filmState: filmState ?? this.filmState,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    flipped: flipped ?? this.flipped,
    layers: layers ?? this.layers,
  );

  /// Turns the photo and its layers a quarter clockwise.
  PhotoDocument rotated() => copyWith(
    // Turning after a mirror is mirroring after turning the other way.
    quarterTurns: (quarterTurns + (flipped ? 3 : 1)) % 4,
    layers: layers.map((l) => l.rotatedQuarter()).toList(),
  );

  /// Mirrors the photo and its layers horizontally.
  PhotoDocument mirrored() => copyWith(flipped: !flipped, layers: layers.map((l) => l.flippedHorizontally()).toList());
}

/// Whether two filmkit states crop the photo differently, which moves everything drawn on it.
bool cropChanged(EditorState? a, EditorState? b) {
  final before = a ?? const EditorState();
  final after = b ?? const EditorState();
  return (before.aspect ?? CropAspect.original) != (after.aspect ?? CropAspect.original) ||
      before.cropZoom != after.cropZoom ||
      before.cropCenter != after.cropCenter;
}
