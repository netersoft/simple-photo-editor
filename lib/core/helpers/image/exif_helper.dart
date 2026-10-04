import 'dart:io';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:path/path.dart' as p;

import '../../services/i18n/translations.g.dart';

/// Reads what the image info dialog shows: file name, size and dimensions, then the camera
/// data (EXIF) the Java app listed.
abstract class ExifHelper {
  /// The EXIF tags shown, without their `Image ` / `EXIF ` prefix.
  static const _tags = [
    'ImageDescription',
    'Make',
    'Model',
    'Orientation',
    'XResolution',
    'YResolution',
    'ResolutionUnit',
    'Software',
    'DateTime',
    'DateTimeOriginal',
    'DateTimeDigitized',
    'SubSecTimeOriginal',
    'SubSecTimeDigitized',
    'ExposureTime',
    'FNumber',
    'ExposureProgram',
    'ISOSpeedRatings',
    'ExposureBiasValue',
    'ExposureMode',
    'MeteringMode',
    'WhiteBalance',
    'Flash',
    'FocalLength',
    'DigitalZoomRatio',
    'SceneCaptureType',
    'ColorSpace',
    'ExifImageWidth',
    'ExifImageLength',
    'ComponentsConfiguration',
    'ExifVersion',
  ];

  static Future<List<(String, String)>> read(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final dimensions = '${descriptor.width} × ${descriptor.height}';
    descriptor.dispose();
    buffer.dispose();

    final entries = <(String, String)>[
      (t.editor.fileName, p.basename(path)),
      (t.editor.fileSize, formatSize(bytes.length)),
      (t.editor.dimensions, dimensions),
    ];

    final exif = await readExifFromBytes(bytes);
    final byName = {for (final entry in exif.entries) entry.key.substring(entry.key.indexOf(' ') + 1): entry.value};
    for (final tag in _tags) {
      final value = byName[tag]?.printable.trim();
      if (value != null && value.isNotEmpty) entries.add((label(tag), value));
    }
    return entries;
  }

  /// "ISOSpeedRatings" → "ISO Speed Ratings".
  static String label(String tag) => tag.replaceAllMapped(RegExp('(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'), (_) => ' ');

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// The entries as plain text, to copy or share.
  static String asText(List<(String, String)> entries) => entries.map((e) => '${e.$1}\n    ${e.$2}').join('\n\n');
}
