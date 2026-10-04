import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/editor/legacy_looks.dart';
import 'package:simple_photo_editor/core/services/i18n/translations.g.dart';

void main() {
  test('the 16 color filters of the Java app, named in each language', () async {
    final enTranslations = await AppLocale.en.build();
    final en = LegacyLooks.of(enTranslations);
    final fr = LegacyLooks.of(AppLocale.fr.buildSync());
    expect(en, hasLength(16));
    expect(en.map((l) => l.name), contains('Sepia'));
    expect(fr.map((l) => l.name), contains('Sépia'));
    // Unique names: filmkit matches the selected look by name.
    expect(en.map((l) => l.name).toSet(), hasLength(16));
    expect(fr.map((l) => l.name).toSet(), hasLength(16));
    expect(identical(LegacyLooks.of(enTranslations), en), isTrue);
  });
}
