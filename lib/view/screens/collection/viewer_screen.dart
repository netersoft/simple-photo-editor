import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routes/app_route.dart';
import '../../../core/services/gallery/service.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../editor/components/tool_sheets.dart';

/// The collection's photos, full screen, one per page: zoom, share, edit, info and delete.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({required this.assets, required this.initialIndex, super.key});

  final List<AssetEntity> assets;
  final int initialIndex;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<AssetEntity> _assets = [...widget.assets];
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AssetEntity get _current => _assets[_index];

  Future<void> _withFile(Future<void> Function(File file) action) async {
    final file = await _current.file;
    if (file != null) await action(file);
  }

  Future<void> _share(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    return _withFile(
      (file) => SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: _current.mimeType)],
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.collectionScreen.confirmation),
        content: Text(context.t.collectionScreen.deleteImage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.no)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.t.yes)),
        ],
      ),
    );
    if (confirmed != true || !await GalleryService.delete(_current) || !mounted) return;

    setState(() {
      _assets.removeAt(_index);
      if (_index >= _assets.length) _index = _assets.length - 1;
    });
    if (_assets.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${_assets.length}', style: const TextStyle(color: Colors.white, fontSize: 18)),
      actions: [
        IconButton(
          tooltip: context.t.editor.adjust,
          icon: const Icon(Icons.edit),
          onPressed: () => _withFile((file) => EditorRoute($extra: file.path).push<void>(context)),
        ),
        IconButton(
          tooltip: context.t.editor.info,
          icon: const Icon(Icons.info_outline),
          onPressed: () => _withFile((file) => showImageInfoDialog(context, file.path)),
        ),
        Builder(
          builder: (buttonContext) => IconButton(
            tooltip: context.t.share,
            icon: const Icon(Icons.share),
            onPressed: () => _share(buttonContext),
          ),
        ),
        IconButton(tooltip: context.t.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ],
    ),
    body: _assets.isEmpty
        ? const SizedBox.shrink()
        : PageView.builder(
            controller: _controller,
            itemCount: _assets.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _AssetPage(asset: _assets[index]),
          ),
  );
}

class _AssetPage extends StatefulWidget {
  const _AssetPage({required this.asset});

  final AssetEntity asset;

  @override
  State<_AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<_AssetPage> {
  late final Future<File?> _file = widget.asset.file;

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _file,
    builder: (context, snapshot) => snapshot.data == null
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.file(snapshot.data!)),
          ),
  );
}
