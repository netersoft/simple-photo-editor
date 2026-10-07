import 'dart:async';

import 'package:simple_photo_editor/core/services/i18n/translations.g.dart';

/// Runs before every test file: tests use the French strings, while the app
/// itself falls back to English (the slang base locale).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await LocaleSettings.setLocale(AppLocale.fr);
  await testMain();
}
