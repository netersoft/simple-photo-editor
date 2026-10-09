import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// The review prompt shows once, after a photo was saved, and only for someone who uses the
  /// app: opened 5 times, at least 3 days after its first launch.
  static const _minLaunches = 5;
  static const _minDays = 3;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

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

  /// Counts a launch, for the review prompt.
  static Future<void> onLaunch() async {
    final prefs = locator<SharedPreferencesService>();
    final now = clock();
    final launches = (prefs.getInt(PrefKeys.launchCount) ?? 0) + 1;
    if (prefs.getInt(PrefKeys.firstLaunchDate) == null) await prefs.setInt(PrefKeys.firstLaunchDate, now.millisecondsSinceEpoch);
    await prefs.setInt(PrefKeys.launchCount, launches);
  }

  /// Called when the user leaves the sharing screen: they saved a photo, the moment to ask for
  /// a review. Asks once in the app's life, when the conditions are met; the store then
  /// decides whether the sheet actually shows.
  static Future<void> onPhotoSaved() async {
    final prefs = locator<SharedPreferencesService>();
    if (prefs.getBool(PrefKeys.reviewRequested) ?? false) return;
    final firstLaunch = prefs.getInt(PrefKeys.firstLaunchDate);
    final launches = prefs.getInt(PrefKeys.launchCount) ?? 0;
    if (firstLaunch == null || launches < _minLaunches) return;
    if (clock().difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch)).inDays < _minDays) return;
    if (!await InAppReview.instance.isAvailable()) return;
    await prefs.setBool(PrefKeys.reviewRequested, true);
    await InAppReview.instance.requestReview();
  }
}
