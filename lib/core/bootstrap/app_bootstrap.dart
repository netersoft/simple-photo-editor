import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';

import '../services/di/locator.dart';
import '../services/i18n/translations.g.dart';
import '../services/shared_preferences/keys.dart';
import '../services/shared_preferences/service.dart';

class AppBootstrapConfig {
  final String envFileName;
  final bool preserveNativeSplash;
  final bool skipBindingInit;

  const AppBootstrapConfig({
    this.envFileName = '.env',
    this.preserveNativeSplash = true,
    this.skipBindingInit = false,
  });
}

Future<void> bootstrapApp({
  AppBootstrapConfig config = const AppBootstrapConfig(),
}) async {
  final WidgetsBinding widgetsBinding = config.skipBindingInit ? WidgetsBinding.instance : WidgetsFlutterBinding.ensureInitialized();

  if (config.preserveNativeSplash) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  GoRouter.optionURLReflectsImperativeAPIs = true;

  await dotenv.load(fileName: config.envFileName);

  await setupLocator();

  // The language picked in the settings, else the device's.
  final language = locator<SharedPreferencesService>().getString(PrefKeys.language);
  if (language == null) {
    await LocaleSettings.useDeviceLocale();
  } else {
    await LocaleSettings.setLocaleRaw(language);
  }
}
