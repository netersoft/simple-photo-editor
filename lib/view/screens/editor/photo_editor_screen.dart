import 'dart:async';

import 'package:filmkit/filmkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/editor/layers.dart';
import '../../../core/editor/legacy_looks.dart';
import '../../../core/helpers/image/photo_picker.dart';
import '../../../core/helpers/logging/log_helper.dart';
import '../../../core/providers/editor/photo_editor_provider.dart';
import '../../../core/routes/app_route.dart';
import '../../../core/services/i18n/translations.g.dart';
import 'components/editor_canvas.dart';
import 'components/tool_sheets.dart';

enum _Tool { adjust, rotate, brush, eraser, text, emoji, sticker }

/// Edits a photo: filmkit's crop, filters and adjustments, then rotation, drawing, texts,
/// emojis and stickers, with undo and redo. Saving writes it to the gallery album.
class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({required this.sourcePath, super.key});

  final String sourcePath;

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  _Tool? _tool;

  PhotoEditor get _editor => ref.read(photoEditorProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(widget.sourcePath));
  }

  Future<void> _open(String path) async {
    try {
      await _editor.open(path);
      setState(() => _tool = null);
    } catch (e, stack) {
      LogHelper.e('Opening the photo failed', error: e, stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.filmkit.loadFailed)));
      Navigator.of(context).pop();
    }
  }

  Future<void> _replacePhoto(ImageSource source) async {
    final (result, path) = await PhotoPicker.pick(source);
    if (!mounted) return;
    if (result == PickResult.denied) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.permissionDenied)));
    }
    if (path != null) await _open(path);
  }

  Future<void> _onTool(_Tool tool) async {
    final drawMode = switch (tool) {
      _Tool.brush => DrawMode.brush,
      _Tool.eraser => DrawMode.eraser,
      _ => DrawMode.none,
    };
    _editor.setDrawMode(drawMode);
    setState(() => _tool = tool);

    switch (tool) {
      case _Tool.adjust:
        await _openFilmkit();
      case _Tool.rotate:
        await showRotateSheet(context);
      case _Tool.brush:
        await showBrushSheet(context);
      case _Tool.eraser:
        break;
      case _Tool.text:
        final text = await showTextDialog(context);
        if (text != null) _editor.addItem(ItemKind.text, text.$1, color: text.$2);
      case _Tool.emoji:
        final emoji = await showEmojiSheet(context);
        if (emoji != null) _editor.addItem(ItemKind.emoji, emoji);
      case _Tool.sticker:
        final sticker = await showStickerSheet(context, ref.read(photoEditorProvider).stickers.keys);
        if (sticker != null) _editor.addItem(ItemKind.sticker, sticker);
    }

    // Only the brush and the eraser stay active; the other tools are one-off actions.
    if (drawMode == DrawMode.none && mounted) setState(() => _tool = null);
  }

  Future<void> _openFilmkit() async {
    final state = ref.read(photoEditorProvider);
    final t = context.t;
    final options = _editor.filmkitOptions(
      EditorOptions(
        looks: LegacyLooks.of(t),
        aspects: const [
          CropAspect.original,
          CropAspect.square,
          CropAspect.portrait,
          CropAspect('3:4', 3 / 4),
          CropAspect('4:3', 4 / 3),
          CropAspect.landscape,
          CropAspect('9:16', 9 / 16),
        ],
        texts: EditorTexts(
          done: t.done,
          crop: t.filmkit.crop,
          filters: t.filmkit.filters,
          adjust: t.filmkit.adjust,
          normal: t.filmkit.normal,
          brightness: t.filmkit.brightness,
          contrast: t.filmkit.contrast,
          saturation: t.filmkit.saturation,
          warmth: t.filmkit.warmth,
          exporting: t.filmkit.exporting,
          cancel: t.cancel,
          exportFailed: t.filmkit.exportFailed,
          loadFailed: t.filmkit.loadFailed,
        ),
      ),
    );
    final result = await FilmkitEditor.open(context, path: state.sourcePath!, isVideo: false, options: options, initialState: state.document!.filmState);
    if (result == null) return;
    final cleared = await _editor.applyFilmkit(result);
    if (cleared && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.editor.cropResetsLayers)));
  }

  Future<void> _editText(int index, ItemLayer item) async {
    final text = await showTextDialog(context, text: item.content, color: item.color);
    if (text != null) _editor.replaceItem(index, item.copyWith(content: text.$1, color: text.$2));
  }

  Future<bool> _save() async {
    unawaited(EasyLoading.show(status: context.t.editor.saving));
    try {
      final path = await _editor.save();
      unawaited(EasyLoading.showSuccess(t.editor.imageSaved));
      if (mounted) unawaited(SharingRoute($extra: path).push<void>(context));
      return true;
    } catch (e, stack) {
      LogHelper.e('Saving the photo failed', error: e, stackTrace: stack);
      unawaited(EasyLoading.showError(t.editor.imageSavingFailure));
      return false;
    }
  }

  /// Like the Java app: unsaved changes ask whether to save, cancel or discard.
  Future<void> _onBack() async {
    if (_tool != null) {
      _editor.setDrawMode(DrawMode.none);
      setState(() => _tool = null);
      return;
    }
    final navigator = Navigator.of(context);
    if (!ref.read(photoEditorProvider).hasUnsavedChanges) {
      navigator.pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.t.editor.saveDialogMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop('discard'), child: Text(context.t.editor.discard)),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop('save'), child: Text(context.t.save)),
        ],
      ),
    );
    if (choice == 'discard') navigator.pop();
    if (choice == 'save') await _save();
  }

  String _title(BuildContext context) => switch (_tool) {
    _Tool.adjust => context.t.editor.adjust,
    _Tool.rotate => context.t.editor.rotate,
    _Tool.brush => context.t.editor.brush,
    _Tool.eraser => context.t.editor.eraser,
    _Tool.text => context.t.editor.text,
    _Tool.emoji => context.t.editor.emoji,
    _Tool.sticker => context.t.editor.sticker,
    null => context.t.appNameAlt,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoEditorProvider);
    final ready = state.document != null && state.image != null && !state.loading;
    const iconColor = Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: iconColor,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _onBack),
          title: Text(_title(context), style: const TextStyle(color: iconColor, fontSize: 18)),
          actions: [
            IconButton(
              tooltip: context.t.editor.info,
              icon: const Icon(Icons.info_outline),
              onPressed: ready ? () => showImageInfoDialog(context, state.sourcePath!) : null,
            ),
            IconButton(
              tooltip: context.t.save,
              icon: const Icon(Icons.save_alt),
              onPressed: ready ? _save : null,
            ),
          ],
        ),
        body: !ready
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.t.camera,
                          color: iconColor,
                          icon: const Icon(Icons.camera_alt_outlined),
                          onPressed: () => _replacePhoto(ImageSource.camera),
                        ),
                        IconButton(
                          tooltip: context.t.gallery,
                          color: iconColor,
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () => _replacePhoto(ImageSource.gallery),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: context.t.editor.undo,
                          color: iconColor,
                          disabledColor: Colors.white24,
                          icon: const Icon(Icons.undo),
                          onPressed: state.canUndo ? _editor.undo : null,
                        ),
                        IconButton(
                          tooltip: context.t.editor.redo,
                          color: iconColor,
                          disabledColor: Colors.white24,
                          icon: const Icon(Icons.redo),
                          onPressed: state.canRedo ? _editor.redo : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: EditorCanvas(onEditText: _editText),
                          ),
                        ),
                        if (state.selected != null)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FloatingActionButton.small(
                                tooltip: context.t.editor.deleteItem,
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                onPressed: _editor.deleteSelected,
                                child: const Icon(Icons.delete_outline),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _ToolBar(selected: _tool, onTool: _onTool),
                ],
              ),
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.selected, required this.onTool});

  final _Tool? selected;
  final ValueChanged<_Tool> onTool;

  @override
  Widget build(BuildContext context) {
    final tools = [
      (_Tool.adjust, Icons.tune, context.t.editor.adjust),
      (_Tool.rotate, Icons.crop_rotate, context.t.editor.rotate),
      (_Tool.brush, Icons.brush, context.t.editor.brush),
      (_Tool.eraser, Icons.auto_fix_normal, context.t.editor.eraser),
      (_Tool.text, Icons.title, context.t.editor.text),
      (_Tool.emoji, Icons.emoji_emotions_outlined, context.t.editor.emoji),
      (_Tool.sticker, Icons.star_outline, context.t.editor.sticker),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final (tool, icon, label) in tools)
              InkWell(
                onTap: () => onTool(tool),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: tool == selected ? Colors.amber : Colors.white),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tool == selected ? Colors.amber : Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
