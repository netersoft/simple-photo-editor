import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../../core/enums/app_brightness.dart';
import '../../../core/helpers/store/store_helper.dart';
import '../../../core/providers/settings/settings_provider.dart';
import '../../../core/services/gallery/service.dart';
import '../../../core/services/i18n/config.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../components/misc/floating_modal.dart';
import '../../themes/app_theme.dart';

/// Preferences (language, theme) and the app's links: rate, share, other apps, about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      elevation: 0.0,
      title: Text(context.t.settings, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppTheme.getAppbarBgColor(),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: const SettingsListWrapper(),
  );
}

class SettingsListWrapper extends ConsumerWidget {
  const SettingsListWrapper({super.key});

  /// A bottom sheet with one radio button per choice; picking another one calls [onChanged].
  static void _showChoices(
    BuildContext context, {
    required String selected,
    required List<(String, String)> choices,
    required ValueChanged<String> onChanged,
  }) => showFloatingModalBottomSheet<void>(
    context: context,
    builder: (context) => Material(
      child: SafeArea(
        top: false,
        child: RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value == null || value == selected) return;
            context.pop();
            onChanged(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final (value, label) in choices) RadioListTile(title: Text(label), value: value)],
          ),
        ),
      ),
    ),
  );

  static void _showAbout(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/lens.svg', width: 96),
          const SizedBox(height: 16),
          Text(context.t.appNameAlt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(snapshot.hasData ? 'Version ${snapshot.data!.version}' : ''),
          ),
          const SizedBox(height: 16),
          Text(context.t.appDescription, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            context.t.settingsScreen.savedIn(album: GalleryService.albumName),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.getTextColor().withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text('© ${StoreHelper.developerName.replaceAll('+', ' ')}', style: const TextStyle(fontSize: 13)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.close))],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider.notifier);
    final languageCode = LocaleSettings.instance.currentLocale.languageCode;
    final currentLang = I18nConfig.langItems.firstWhereOrNull((item) => item.code == languageCode);
    final brightness = settings.getAppBrightness() ?? AppBrightness.system.name;
    final brightnessChoices = [
      (AppBrightness.light.name, context.t.light),
      (AppBrightness.dark.name, context.t.dark),
      (AppBrightness.system.name, context.t.system),
    ];

    Widget trailing(String value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text(value), const Icon(Icons.chevron_right)],
    );

    final sectionTitles = SettingsThemeData(
      titleTextColor: AppTheme.pickColor(light: AppTheme.primaryColor, dark: Colors.white70),
    );

    return SettingsList(
      lightTheme: sectionTitles,
      darkTheme: sectionTitles,
      sections: [
        SettingsSection(
          title: Text(context.t.settingsScreen.preferences),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.language),
              title: Text(context.t.language),
              trailing: trailing(currentLang?.label[languageCode] ?? ''),
              onPressed: (context) => _showChoices(
                context,
                selected: languageCode,
                choices: [for (final item in I18nConfig.langItems) (item.code, item.label[languageCode]!)],
                onChanged: settings.changeLanguage,
              ),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.brightness_6),
              title: Text(context.t.theme),
              trailing: trailing(brightnessChoices.firstWhere((c) => c.$1 == brightness).$2),
              onPressed: (context) => _showChoices(context, selected: brightness, choices: brightnessChoices, onChanged: settings.setAppBrightness),
            ),
          ],
        ),
        SettingsSection(
          title: Text(context.t.settingsScreen.application),
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.star_outline),
              title: Text(context.t.rateUs),
              onPressed: (_) => StoreHelper.rate(),
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.share),
              title: Text(context.t.settingsScreen.shareApp),
              onPressed: (context) {
                final box = context.findRenderObject() as RenderBox?;
                settings.shareApp(origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
              },
            ),
            if (StoreHelper.hasMoreApps)
              SettingsTile.navigation(
                leading: const Icon(Icons.apps),
                title: Text(context.t.moreApps),
                onPressed: (_) => StoreHelper.moreApps(),
              ),
            SettingsTile.navigation(
              leading: const Icon(Icons.info_outline),
              title: Text(context.t.about),
              onPressed: _showAbout,
            ),
          ],
        ),
      ],
    );
  }
}
