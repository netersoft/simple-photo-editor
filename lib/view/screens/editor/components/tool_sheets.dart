import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/editor/palettes.dart';
import '../../../../core/helpers/image/exif_helper.dart';
import '../../../../core/providers/editor/photo_editor_provider.dart';
import '../../../../core/services/i18n/translations.g.dart';

const _sheetBackground = Color(0xFF151414);

Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: _sheetBackground,
  barrierColor: Colors.black26,
  showDragHandle: true,
  builder: (context) => SafeArea(child: builder(context)),
);

class ColorRow extends StatelessWidget {
  const ColorRow({required this.selected, required this.onSelected, super.key});

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final color in editorColors)
          GestureDetector(
            onTap: () => onSelected(color),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: color.toARGB32() == selected.toARGB32() ? Colors.white : Colors.white24, width: 3),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Brush color, size and opacity.
Future<void> showBrushSheet(BuildContext context) => _showSheet(
  context,
  (context) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(photoEditorProvider);
      final editor = ref.read(photoEditorProvider.notifier);
      const label = TextStyle(color: Colors.white70);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorRow(
              selected: state.brushColor,
              onSelected: (c) => editor.setBrush(color: c),
            ),
            ListTile(
              title: Text(context.t.editor.size, style: label),
              subtitle: Slider(
                value: state.brushWidth,
                min: 0.003,
                max: 0.06,
                activeColor: Colors.white,
                onChanged: (v) => editor.setBrush(width: v),
              ),
            ),
            ListTile(
              title: Text(context.t.editor.opacity, style: label),
              subtitle: Slider(
                value: state.brushOpacity,
                min: 0.1,
                activeColor: Colors.white,
                onChanged: (v) => editor.setBrush(opacity: v),
              ),
            ),
          ],
        ),
      );
    },
  ),
);

/// Asks for a text and its color; `null` if cancelled or empty.
Future<(String, Color)?> showTextDialog(BuildContext context, {String text = '', Color color = Colors.white}) => showDialog<(String, Color)>(
  context: context,
  barrierColor: Colors.black87,
  builder: (context) => _TextDialog(text: text, color: color),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.text);
  late Color _color = widget.color;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : (text, _color));
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.transparent,
    child: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _done,
              child: Text(context.t.done, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
          Expanded(
            child: Center(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                style: TextStyle(color: _color, fontSize: 32, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: context.t.editor.typeText,
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
          ColorRow(selected: _color, onSelected: (c) => setState(() => _color = c)),
        ],
      ),
    ),
  );
}

Future<String?> showEmojiSheet(BuildContext context) => _showSheet<String>(
  context,
  (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.45,
    child: GridView.count(
      crossAxisCount: 8,
      padding: const EdgeInsets.all(8),
      children: [
        for (final emoji in editorEmojis)
          InkWell(
            onTap: () => Navigator.of(context).pop(emoji),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
          ),
      ],
    ),
  ),
);

/// Returns the chosen sticker's asset path.
Future<String?> showStickerSheet(BuildContext context, Iterable<String> stickers) => _showSheet<String>(
  context,
  (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.45,
    child: GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final sticker in stickers)
          InkWell(
            onTap: () => Navigator.of(context).pop(sticker),
            child: Image.asset(sticker),
          ),
      ],
    ),
  ),
);

/// Rotate a quarter clockwise and mirror; stays open to repeat them.
Future<void> showRotateSheet(BuildContext context) => _showSheet(
  context,
  (context) => Consumer(
    builder: (context, ref, _) {
      final editor = ref.read(photoEditorProvider.notifier);
      Widget button(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 30),
        label: Text(label, style: const TextStyle(color: Colors.white)),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            button(Icons.rotate_90_degrees_cw, context.t.editor.rotateRight, editor.rotate),
            button(Icons.flip, context.t.editor.flip, editor.mirror),
          ],
        ),
      );
    },
  ),
);

/// File and camera data of the photo at [path], with copy and share.
Future<void> showImageInfoDialog(BuildContext context, String path) async {
  List<(String, String)> entries;
  try {
    entries = await ExifHelper.read(path);
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.editor.exifExtractError)));
    return;
  }
  if (!context.mounted) return;
  final text = ExifHelper.asText(entries);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.editor.aboutTheImage),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (label, value) in entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: SelectableText(value),
              ),
            if (entries.length <= 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.t.editor.noExifData, style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.copiedToClipboard)));
          },
          child: Text(context.t.copy),
        ),
        TextButton(
          onPressed: () => SharePlus.instance.share(ShareParams(text: text)),
          child: Text(context.t.share),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.close)),
      ],
    ),
  );
}
