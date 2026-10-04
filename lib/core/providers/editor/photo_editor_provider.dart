import 'dart:io';
import 'dart:ui' as ui;

import 'package:filmkit/filmkit.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../editor/layers.dart';
import '../../editor/layers_painter.dart';
import '../../editor/photo_document.dart';
import '../../services/gallery/service.dart';

part 'photo_editor_provider.g.dart';

enum DrawMode { none, brush, eraser }

/// The longest side of the edited photo.
const _maxDimension = 2048;

const _stickersFolder = 'assets/stickers/';

@riverpod
class PhotoEditor extends _$PhotoEditor {
  final Map<String, ui.Image> _images = {};
  Map<String, ui.Image> _stickers = {};
  Directory? _dir;
  int _fileCounter = 0;

  @override
  PhotoEditorState build() {
    ref.onDispose(() {
      for (final image in _images.values) {
        image.dispose();
      }
      for (final sticker in _stickers.values) {
        sticker.dispose();
      }
      _dir?.delete(recursive: true).ignore();
    });
    return const PhotoEditorState();
  }

  /// Opens [sourcePath], replacing the current photo and its history.
  Future<void> open(String sourcePath) async {
    state = state.copyWith(loading: true);
    _dir ??= await Directory('${(await getTemporaryDirectory()).path}/editor_${DateTime.now().millisecondsSinceEpoch}').create(recursive: true);

    // A JPEG with the EXIF orientation applied and a bounded size, whatever the source (HEIC, PNG…).
    final base = await Filmkit.exportImage(
      input: sourcePath,
      output: _newFile('jpg'),
      edit: const EditSpec(maxDimension: _maxDimension),
      quality: 95,
    );
    await _loadImage(base.path);
    if (_stickers.isEmpty) _stickers = await _loadStickers();

    state = PhotoEditorState(
      sourcePath: sourcePath,
      history: [PhotoDocument(basePath: base.path)],
      images: Map.of(_images),
      stickers: _stickers,
    );
  }

  /// filmkit's options for this photo: unique output files, the same size as the base photo.
  EditorOptions filmkitOptions(EditorOptions options) => options.copyWith(outputPath: _newFile('jpg'), maxDimension: _maxDimension, quality: 95);

  /// Applies filmkit's result. Returns `true` if the crop changed and removed the layers.
  Future<bool> applyFilmkit(EditorResult result) async {
    final export = result.export;
    if (export == null) return false;
    await _loadImage(export.path);
    final doc = state.document!;
    final cleared = doc.layers.isNotEmpty && cropChanged(doc.filmState, result.state);
    _push(
      doc.copyWith(basePath: export.path, filmState: result.state, layers: cleared ? const [] : null),
      images: Map.of(_images),
    );
    return cleared;
  }

  void rotate() => _push(state.document!.rotated());

  void mirror() => _push(state.document!.mirrored());

  void setDrawMode(DrawMode mode) => state = state.copyWith(drawMode: mode, selected: () => null);

  void setBrush({Color? color, double? width, double? opacity}) => state = state.copyWith(
    brushColor: color,
    brushWidth: width,
    brushOpacity: opacity,
  );

  // Strokes and item gestures update a draft, committed to the history when they end.

  void startStroke(Offset point) {
    final eraser = state.drawMode == DrawMode.eraser;
    final stroke = StrokeLayer(
      points: [point],
      color: eraser ? const Color(0xFF000000) : state.brushColor.withValues(alpha: state.brushOpacity),
      width: eraser ? state.brushWidth * 2 : state.brushWidth,
      eraser: eraser,
    );
    _draft(state.document!.copyWith(layers: [...state.document!.layers, stroke]));
  }

  void extendStroke(Offset point) {
    final layers = state.document!.layers;
    if (layers.isEmpty || layers.last is! StrokeLayer) return;
    _draft(state.document!.copyWith(layers: [...layers.sublist(0, layers.length - 1), (layers.last as StrokeLayer).withPoint(point)]));
  }

  void addItem(ItemKind kind, String content, {Color? color}) {
    final item = ItemLayer(kind: kind, content: content, color: color ?? const Color(0xFFFFFFFF));
    final layers = [...state.document!.layers, item];
    _push(state.document!.copyWith(layers: layers));
    state = state.copyWith(drawMode: DrawMode.none, selected: () => layers.length - 1);
  }

  void select(int? index) => state = state.copyWith(selected: () => index);

  /// Moves, scales or turns the item at [index] during a gesture.
  void updateItem(int index, ItemLayer item) {
    final layers = [...state.document!.layers];
    layers[index] = item;
    _draft(state.document!.copyWith(layers: layers));
  }

  /// Replaces the item at [index] right away, e.g. after editing a text.
  void replaceItem(int index, ItemLayer item) {
    final layers = [...state.document!.layers];
    layers[index] = item;
    _push(state.document!.copyWith(layers: layers));
  }

  void deleteSelected() {
    final index = state.selected;
    if (index == null) return;
    final layers = [...state.document!.layers]..removeAt(index);
    _push(state.document!.copyWith(layers: layers));
    state = state.copyWith(selected: () => null);
  }

  /// Ends a stroke or an item gesture.
  void commit() {
    final draft = state.draft;
    if (draft != null) _push(draft);
  }

  void undo() {
    if (state.canUndo) state = state.copyWith(index: state.index - 1, selected: () => null);
  }

  void redo() {
    if (state.canRedo) state = state.copyWith(index: state.index + 1, selected: () => null);
  }

  /// Renders the photo with its layers at full size, saves it in the gallery album and
  /// returns the saved JPEG's path.
  Future<String> save() async {
    final doc = state.document!;
    final image = _images[doc.basePath]!;
    final turned = doc.quarterTurns.isOdd;
    final size = Size((turned ? image.height : image.width).toDouble(), (turned ? image.width : image.height).toDouble());

    final recorder = ui.PictureRecorder();
    LayersPainter(
      image: image,
      quarterTurns: doc.quarterTurns,
      flipped: doc.flipped,
      layers: doc.layers,
      stickers: state.stickers,
    ).paint(Canvas(recorder), size);
    final rendered = await recorder.endRecording().toImage(size.width.round(), size.height.round());
    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();

    final pngPath = _newFile('png');
    await File(pngPath).writeAsBytes(png!.buffer.asUint8List());
    final jpeg = await Filmkit.exportImage(
      input: pngPath,
      output: '${_dir!.path}/SPE_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 95,
    );
    await File(pngPath).delete();
    await GalleryService.save(jpeg.path);

    state = state.copyWith(savedIndex: state.index);
    return jpeg.path;
  }

  void _draft(PhotoDocument doc) => state = state.copyWith(draft: () => doc);

  void _push(PhotoDocument doc, {Map<String, ui.Image>? images}) => state = state.copyWith(
    history: [...state.history.sublist(0, state.index + 1), doc],
    index: state.index + 1,
    draft: () => null,
    images: images,
  );

  String _newFile(String extension) => '${_dir!.path}/${_fileCounter++}.$extension';

  Future<void> _loadImage(String path) async {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    _images[path] = (await codec.getNextFrame()).image;
    codec.dispose();
  }

  static Future<Map<String, ui.Image>> _loadStickers() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final stickers = <String, ui.Image>{};
    for (final asset in manifest.listAssets().where((a) => a.startsWith(_stickersFolder))) {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      stickers[asset] = (await codec.getNextFrame()).image;
      codec.dispose();
    }
    return stickers;
  }
}

class PhotoEditorState {
  const PhotoEditorState({
    this.sourcePath,
    this.history = const [],
    this.index = 0,
    this.savedIndex = 0,
    this.draft,
    this.images = const {},
    this.stickers = const {},
    this.drawMode = DrawMode.none,
    this.brushColor = const Color(0xFFED0A3F),
    this.brushWidth = 0.015,
    this.brushOpacity = 1,
    this.selected,
    this.loading = false,
  });

  /// The photo the user picked, as is (for its camera data).
  final String? sourcePath;
  final List<PhotoDocument> history;
  final int index;

  /// The history index last saved to the gallery.
  final int savedIndex;

  /// The document while a stroke or a gesture is in progress.
  final PhotoDocument? draft;

  /// Decoded base photos, by path.
  final Map<String, ui.Image> images;

  /// Decoded stickers, by asset path.
  final Map<String, ui.Image> stickers;
  final DrawMode drawMode;
  final Color brushColor;

  /// Relative to the photo's shortest side.
  final double brushWidth;
  final double brushOpacity;

  /// Index of the selected item in the layers.
  final int? selected;
  final bool loading;

  PhotoDocument? get document => draft ?? (history.isEmpty ? null : history[index]);

  ui.Image? get image => images[document?.basePath];

  ItemLayer? get selectedItem => selected == null ? null : document?.layers[selected!] as ItemLayer?;

  bool get canUndo => index > 0;

  bool get canRedo => index < history.length - 1;

  bool get hasUnsavedChanges => index != savedIndex;

  PhotoEditorState copyWith({
    List<PhotoDocument>? history,
    int? index,
    int? savedIndex,
    PhotoDocument? Function()? draft,
    Map<String, ui.Image>? images,
    DrawMode? drawMode,
    Color? brushColor,
    double? brushWidth,
    double? brushOpacity,
    int? Function()? selected,
    bool? loading,
  }) => PhotoEditorState(
    sourcePath: sourcePath,
    history: history ?? this.history,
    index: index ?? this.index,
    savedIndex: savedIndex ?? this.savedIndex,
    draft: draft != null ? draft() : this.draft,
    images: images ?? this.images,
    stickers: stickers,
    drawMode: drawMode ?? this.drawMode,
    brushColor: brushColor ?? this.brushColor,
    brushWidth: brushWidth ?? this.brushWidth,
    brushOpacity: brushOpacity ?? this.brushOpacity,
    selected: selected != null ? selected() : this.selected,
    loading: loading ?? this.loading,
  );
}
