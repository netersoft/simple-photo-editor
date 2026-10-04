import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../services/gallery/service.dart';

part 'collection_provider.g.dart';

/// The photos of the app's gallery album, newest first.
@riverpod
Future<List<AssetEntity>> collection(Ref ref) => GalleryService.list();
