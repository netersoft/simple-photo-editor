import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../enums/app_brightness.dart';
import '../../helpers/router/navigation_helper.dart';
import '../../helpers/store/store_helper.dart';
import '../../routes/app_route.dart';
import '../../services/di/locator.dart';
import '../../services/i18n/translations.g.dart';
import '../../services/shared_preferences/keys.dart';
import '../../services/shared_preferences/service.dart';

part 'settings_provider.g.dart';

final _navigationHelper = locator<NavigationHelper>();

@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  SettingsState build() => const SettingsState();

  final SharedPreferencesService prefs = locator<SharedPreferencesService>();

  /// Shares the app's Play Store link through the system share sheet, from [origin]
  /// (the tapped tile, for the iPad popover).
  Future<void> shareApp({Rect? origin}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: '${t.installApp}\n${StoreHelper.playStoreUrl}', subject: t.appNameAlt, sharePositionOrigin: origin));
    } catch (_) {
      unawaited(EasyLoading.showError(t.anErrorOccurred));
    }
  }

  Future<void> changeLanguage(String newValue) async {
    final navigator = _navigationHelper.navigatorKey.currentState;
    await LocaleSettings.setLocaleRaw(newValue);

    try {
      _navigationHelper.go(const SettingsRoute().location);
      if (navigator != null && navigator.mounted) {
        Phoenix.rebirth(navigator.context);
      }
    } catch (e) {
      _navigationHelper.pushReplacement(const RedirectionRoute().location);
    }
  }

  String? getAppBrightness() => prefs.getString(
    PrefKeys.brightness,
    defaultValue: AppBrightness.system.name,
  );

  void setAppBrightness(String appBrightness, {bool relaunch = true}) {
    prefs.setString(PrefKeys.brightness, appBrightness);

    if (relaunch) {
      try {
        _navigationHelper.go(const SettingsRoute().location);
        var ctx = _navigationHelper.navigatorKey.currentContext;
        if (ctx != null) Phoenix.rebirth(ctx);
      } catch (e) {
        _navigationHelper.pushReplacement(const RedirectionRoute().location);
      }
    }
  }
}

class SettingsState {
  final bool isLoading;

  const SettingsState({this.isLoading = false});

  SettingsState copyWith({bool? isLoading}) => SettingsState(isLoading: isLoading ?? this.isLoading);
}
