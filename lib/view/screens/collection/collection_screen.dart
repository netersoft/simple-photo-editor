import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/providers/collection/collection_provider.dart';
import '../../../core/routes/app_route.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../themes/app_theme.dart';

/// The photos saved by the app, in a grid.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.collectionScreen.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.getAppbarBgColor(),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: context.t.collectionScreen.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(collectionProvider),
          ),
        ],
      ),
      body: collection.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.t.anErrorOccurred)),
        data: (assets) => assets.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(context.t.collectionScreen.empty, textAlign: TextAlign.center),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(collectionProvider.future),
                child: GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                  itemCount: assets.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () async {
                      await ViewerRoute(
                        $extra: ViewerExtra(assets: assets, index: index),
                      ).push<void>(context);
                      ref.invalidate(collectionProvider);
                    },
                    child: AssetThumbnail(asset: assets[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class AssetThumbnail extends StatefulWidget {
  const AssetThumbnail({required this.asset, super.key});

  final AssetEntity asset;

  @override
  State<AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<AssetThumbnail> {
  late final Future<Uint8List?> _thumbnail = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(300));

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _thumbnail,
    builder: (context, snapshot) =>
        snapshot.data == null ? ColoredBox(color: Colors.grey.shade300) : Image.memory(snapshot.data!, fit: BoxFit.cover, gaplessPlayback: true),
  );
}
