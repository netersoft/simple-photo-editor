import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/helpers/image/photo_picker.dart';
import '../../core/helpers/store/store_helper.dart';
import '../../core/routes/app_route.dart';
import '../../core/services/gallery/service.dart';
import '../../core/services/i18n/translations.g.dart';
import '../themes/app_theme.dart';

/// Home: take or pick a photo to edit, open the collection or the settings, and the store links.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    AppTheme.setStatusBarColor();
    unawaited(StoreHelper.onLaunch());
  }

  Future<void> _pick(ImageSource source) async {
    final (result, path) = await PhotoPicker.pick(source);
    if (!mounted) return;
    switch (result) {
      case PickResult.picked:
        await EditorRoute($extra: path!).push<void>(context);
      case PickResult.denied:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.permissionDenied)));
      case PickResult.cancelled:
        break;
    }
  }

  Future<void> _openCollection() async {
    if (!await GalleryService.requestAccess()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.permissionDenied)));
      return;
    }
    if (mounted) await const CollectionRoute().push<void>(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.pickColor(light: const Color(0xFF414A4C), dark: AppTheme.getTextColor());

    // The Java app's home: six round buttons on a hexagon around the lens.
    final buttons = <(Offset, Widget)>[
      (
        const Offset(0, -1),
        _HomeButton(icon: Icons.photo_library, label: context.t.collection, color: const Color(0xFF0000CD), onTap: _openCollection),
      ),
      (
        const Offset(-1, -0.5),
        _HomeButton(icon: Icons.camera_alt, label: context.t.camera, color: const Color(0xFF32DC32), onTap: () => _pick(ImageSource.camera)),
      ),
      (
        const Offset(1, -0.5),
        _HomeButton(icon: Icons.image, label: context.t.gallery, color: const Color(0xFF4B0082), onTap: () => _pick(ImageSource.gallery)),
      ),
      (
        const Offset(-1, 0.5),
        _HomeButton(
          icon: Icons.settings,
          label: context.t.settings,
          color: const Color(0xFFFFD700),
          onTap: () => const SettingsRoute().push<void>(context),
        ),
      ),
      (
        const Offset(1, 0.5),
        _HomeButton(icon: Icons.star, label: context.t.rateUs, color: const Color(0xFFFF0000), onTap: StoreHelper.rate),
      ),
      if (StoreHelper.hasMoreApps)
        (
          const Offset(0, 1),
          _HomeButton(icon: Icons.more_horiz, label: context.t.moreApps, color: const Color(0xFFFBB03B), onTap: StoreHelper.moreApps),
        ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.getBgDefaultColor(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t.appNameAlt,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 56),
                SizedBox.square(
                  dimension: 2 * (_hexRadius + _HomeButton.size / 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset('assets/images/lens.svg', width: 108),
                      for (final (direction, button) in buttons)
                        Transform.translate(
                          offset: Offset(direction.dx * _hexRadius, direction.dy * _hexRadius),
                          child: button,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 56),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => Text(
                    snapshot.hasData ? 'Version ${snapshot.data!.version}' : '',
                    style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance from the lens to the top and bottom buttons; the side ones are at the same
/// horizontal distance, half as far vertically, as in the Java app.
const double _hexRadius = 120;

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  static const double size = 90;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
