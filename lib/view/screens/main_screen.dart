import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/helpers/image/photo_picker.dart';
import '../../core/helpers/store/store_helper.dart';
import '../../core/providers/settings/settings_provider.dart';
import '../../core/routes/app_route.dart';
import '../../core/services/gallery/service.dart';
import '../../core/services/i18n/translations.g.dart';
import '../themes/app_theme.dart';

/// Home: take or pick a photo to edit, open the collection, and the store links.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
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
    final buttons = [
      _HomeButton(icon: Icons.photo_library, label: context.t.collection, color: const Color(0xFF0000CD), onTap: _openCollection),
      if (StoreHelper.hasMoreApps) _HomeButton(icon: Icons.more_horiz, label: context.t.moreApps, color: const Color(0xFFFBB03B), onTap: StoreHelper.moreApps),
      _HomeButton(icon: Icons.camera_alt, label: context.t.camera, color: const Color(0xFF32DC32), onTap: () => _pick(ImageSource.camera)),
      _HomeButton(
        icon: Icons.share,
        label: context.t.shareApp,
        color: const Color(0xFFFFD700),
        onTap: () => ref.read(settingsProvider.notifier).share(ShareOptions.free),
      ),
      _HomeButton(icon: Icons.image, label: context.t.gallery, color: const Color(0xFF4B0082), onTap: () => _pick(ImageSource.gallery)),
      _HomeButton(icon: Icons.star, label: context.t.rateUs, color: const Color(0xFFFF0000), onTap: StoreHelper.rate),
    ];

    return Scaffold(
      backgroundColor: AppTheme.getBgDefaultColor(),
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: context.t.settings,
            onPressed: () => const SettingsRoute().push<void>(context),
            icon: Icon(Icons.settings, color: AppTheme.getTextColor()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Text(
              context.t.appNameAlt,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.getTextColor()),
            ),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text(
                snapshot.hasData ? 'Version ${snapshot.data!.version}' : '',
                style: TextStyle(color: AppTheme.getTextColor().withValues(alpha: 0.6)),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset('assets/images/lens.svg', width: 108),
                      Wrap(
                        spacing: 140,
                        runSpacing: 28,
                        alignment: WrapAlignment.center,
                        children: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 96,
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
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
