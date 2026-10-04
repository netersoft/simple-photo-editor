import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/extensions/color_extension.dart';

void main() {
  test('fromHex reads RGB with or without #, and ARGB', () {
    expect(ColorX.fromHex('#0000CD'), const Color(0xFF0000CD));
    expect(ColorX.fromHex('009ee3'), const Color(0xFF009EE3));
    expect(ColorX.fromHex('#80FFFFFF'), const Color(0x80FFFFFF));
  });

  test('isValidHex', () {
    expect(ColorX.isValidHex('#fff'), isTrue);
    expect(ColorX.isValidHex('0000CD'), isTrue);
    expect(ColorX.isValidHex('#80FFFFFF'), isTrue);
    expect(ColorX.isValidHex('#12345'), isFalse);
    expect(ColorX.isValidHex('blue'), isFalse);
  });

  test('toHex writes ARGB', () {
    expect(const Color(0xFF0000CD).toHex(), '#ff0000cd');
    expect(const Color(0xFF0000CD).toHex(leadingHashSign: false), 'ff0000cd');
  });
}
