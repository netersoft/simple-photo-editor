import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/helpers/image/exif_helper.dart';

void main() {
  test('label splits EXIF tag names into words', () {
    expect(ExifHelper.label('ISOSpeedRatings'), 'ISO Speed Ratings');
    expect(ExifHelper.label('DateTimeOriginal'), 'Date Time Original');
    expect(ExifHelper.label('FNumber'), 'F Number');
    expect(ExifHelper.label('Make'), 'Make');
  });

  test('formatSize', () {
    expect(ExifHelper.formatSize(512), '512 B');
    expect(ExifHelper.formatSize(2048), '2.0 KB');
    expect(ExifHelper.formatSize(3 * 1024 * 1024 + 200 * 1024), '3.2 MB');
  });

  test('asText puts each value under its label', () {
    expect(ExifHelper.asText([('Make', 'Pixel'), ('Model', '8a')]), 'Make\n    Pixel\n\nModel\n    8a');
  });
}
