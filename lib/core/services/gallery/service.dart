import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

/// The "Simple Photo Editor" album of the device gallery, where edited photos are saved
/// and which the collection screen lists. On Android it is the `Pictures/Simple Photo Editor`
/// folder, the one the Java app wrote to, so its photos show up in the collection too.
abstract class GalleryService {
  static const albumName = 'Simple Photo Editor';

  static const _permission = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
  );

  /// Asks for access to the photos; `false` if the user refused.
  static Future<bool> requestAccess() async => (await PhotoManager.requestPermissionExtend(requestOption: _permission)).hasAccess;

  /// Saves the image at [path] in the album, and returns it.
  static Future<AssetEntity> save(String path) async {
    final title = p.basename(path);
    if (Platform.isAndroid) {
      return PhotoManager.editor.saveImageWithPath(path, title: title, relativePath: 'Pictures/$albumName');
    }

    final asset = await PhotoManager.editor.saveImageWithPath(path, title: title);
    final album = await _album() ?? await PhotoManager.editor.darwin.createAlbum(albumName);
    if (album == null) return asset;
    return PhotoManager.editor.copyAssetToPath(asset: asset, pathEntity: album);
  }

  /// The album's photos, newest first; empty if the album doesn't exist yet.
  static Future<List<AssetEntity>> list() async {
    final album = await _album();
    if (album == null) return [];
    final count = await album.assetCountAsync;
    if (count == 0) return [];
    final assets = await album.getAssetListRange(start: 0, end: count);
    return assets..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
  }

  /// Deletes [asset] from the device (the system may ask the user to confirm). Returns
  /// whether it was deleted.
  static Future<bool> delete(AssetEntity asset) async => (await PhotoManager.editor.deleteWithIds([asset.id])).contains(asset.id);

  static Future<AssetPathEntity?> _album() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: false);
    for (final path in paths) {
      if (path.name == albumName) return path;
    }
    return null;
  }
}
