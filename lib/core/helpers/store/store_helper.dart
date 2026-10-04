import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/di/locator.dart';
import '../../services/shared_preferences/keys.dart';
import '../../services/shared_preferences/service.dart';

/// Play Store links: rating the app and the developer's other apps.
abstract class StoreHelper {
  /// The Play Store application ID of the production app: the dev and staging flavors have
  /// their own IDs, which have no store listing.
  static const playStoreId = 'com.neteru.simplephotoeditor';

  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=$playStoreId';

  /// Netersoft's developer page on the Play Store.
  static const _developerId = '6685918894519555539';

  /// Like the Java app: the review prompt shows once the app has been opened 10 times,
  /// at least 10 days after its first launch.
  static const _minLaunches = 10;
  static const _minDays = 10;

  /// The app's Play Store listing; on iOS, which has no listing yet, the system review prompt.
  static Future<void> rate() async {
    if (!Platform.isAndroid) return InAppReview.instance.requestReview();
    await _openPlayStore('details?id=$playStoreId');
  }

  static Future<void> moreApps() => _openPlayStore('dev?id=$_developerId');

  /// The Play Store app if installed (launchUrl throws when nothing handles market://), the web page otherwise.
  static Future<void> _openPlayStore(String path) async {
    try {
      if (await launchUrl(Uri.parse('market://$path'))) return;
    } on PlatformException catch (_) {}
    await launchUrl(Uri.parse('https://play.google.com/store/apps/$path'), mode: LaunchMode.externalApplication);
  }

  /// Whether the store has a developer page for this platform.
  static bool get hasMoreApps => Platform.isAndroid;

  /// Counts a launch and asks for a review when the conditions are met.
  static Future<void> onLaunch() async {
    final prefs = locator<SharedPreferencesService>();
    final now = DateTime.now();
    final firstLaunch = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(PrefKeys.firstLaunchDate) ?? now.millisecondsSinceEpoch);
    final launches = (prefs.getInt(PrefKeys.launchCount) ?? 0) + 1;
    await prefs.setInt(PrefKeys.firstLaunchDate, firstLaunch.millisecondsSinceEpoch);
    await prefs.setInt(PrefKeys.launchCount, launches);

    if (prefs.getBool(PrefKeys.reviewRequested) ?? false) return;
    if (launches < _minLaunches || now.difference(firstLaunch).inDays < _minDays) return;
    if (!await InAppReview.instance.isAvailable()) return;
    await prefs.setBool(PrefKeys.reviewRequested, true);
    await InAppReview.instance.requestReview();
  }
}
