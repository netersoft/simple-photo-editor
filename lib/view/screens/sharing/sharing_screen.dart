import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/helpers/store/store_helper.dart';
import '../../../core/routes/app_route.dart';
import '../../../core/services/i18n/translations.g.dart';
import '../../themes/app_theme.dart';

/// Shown after saving: the photo, and sharing it through the system share sheet. Leaving it
/// may bring up the review prompt (see [StoreHelper.onPhotoSaved]): the user has their photo,
/// and is done sharing it.
class SharingScreen extends StatefulWidget {
  const SharingScreen({required this.path, super.key});

  final String path;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  String get path => widget.path;

  @override
  void dispose() {
    unawaited(StoreHelper.onPhotoSaved());
    super.dispose();
  }

  Future<void> _share(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/jpeg')],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t.sharing.title),
      actions: [
        IconButton(
          tooltip: context.t.sharing.backHome,
          icon: const Icon(Icons.home),
          onPressed: () => context.go(const MainRoute().location),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Image.file(File(path))),
            ),
          ),
          Text(context.t.sharing.savedTo, textAlign: TextAlign.center),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) => FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppTheme.primaryColor),
                onPressed: () => _share(context),
                icon: const Icon(Icons.share),
                label: Text(context.t.share),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
