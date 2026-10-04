import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../logging/log_helper.dart';

enum PickResult { picked, cancelled, denied }

/// Takes a photo with the camera or picks one in the gallery.
abstract class PhotoPicker {
  static Future<(PickResult, String?)> pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file == null) return (PickResult.cancelled, null);
      return (PickResult.picked, file.path);
    } on PlatformException catch (e) {
      if (e.code.contains('access_denied')) return (PickResult.denied, null);
      LogHelper.e('Picking a photo failed', error: e);
      rethrow;
    }
  }
}
