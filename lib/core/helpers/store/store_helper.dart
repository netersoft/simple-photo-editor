import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/di/locator.dart';
import '../../services/shared_preferences/keys.dart';
import '../../services/shared_preferences/service.dart';
import '../ui/rate_dialog.dart';

/// Play Store links: rating the app and the developer's other apps.
abstract class StoreHelper {
  /// The Play Store application ID of the production app: the dev and staging flavors have
  /// their own IDs, which have no store listing.
  static const playStoreId = 'com.neteru.simplephotoeditor';

  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=$playStoreId';

  /// Netersoft's developer page on the Play Store.
  static const _developerId = '6685918894519555539';

  /// The review prompt shows after a photo was saved, and only for someone who uses the app:
  /// opened 3 times, at least a day after its first launch.
  ///
  /// The store's in-app sheet is requested once in the app's life: the store decides whether it
  /// shows and it only collects stars. On Android, after it, our own dialog opens the Play Store
  /// listing, where a comment can be written: at most [maxDialogs] times, [dialogGap] apart and
  /// [dialogDelay] after the sheet, until the user rates or asks not to be asked again. iOS forbids
  /// custom rating prompts, so it keeps the system sheet only.
  static const _minLaunches = 3;
  static const _minDays = 1;
  static const maxDialogs = 3;
  static const dialogDelay = Duration(days: 14);
  static const dialogGap = Duration(days: 30);

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static bool isAndroid = Platform.isAndroid;

  /// Shown once the screen that triggered it had time to close.
  @visibleForTesting
  static Future<RateChoice?> Function() ask = () async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return showRateDialog();
  };

  @visibleForTesting
  static Future<void> Function() openListing = () => _openPlayStore('details?id=$playStoreId');

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
    if (prefs.getBool(PrefKeys.rateDone) ?? false) return;
    final firstLaunch = prefs.getInt(PrefKeys.firstLaunchDate);
    final launches = prefs.getInt(PrefKeys.launchCount) ?? 0;
    if (firstLaunch == null || launches < _minLaunches) return;
    final now = clock();
    if (now.difference(DateTime.fromMillisecondsSinceEpoch(firstLaunch)).inDays < _minDays) return;

    if (!(prefs.getBool(PrefKeys.reviewRequested) ?? false)) {
      if (!await InAppReview.instance.isAvailable()) return;
      await prefs.setBool(PrefKeys.reviewRequested, true);
      await prefs.setInt(PrefKeys.reviewRequestedAt, now.millisecondsSinceEpoch);
      await InAppReview.instance.requestReview();
      return;
    }
    if (isAndroid) await _askWithDialog(prefs, now);
  }

  static Future<void> _askWithDialog(SharedPreferencesService prefs, DateTime now) async {
    final sheetAt = prefs.getInt(PrefKeys.reviewRequestedAt);
    if (sheetAt != null && now.difference(DateTime.fromMillisecondsSinceEpoch(sheetAt)) < dialogDelay) return;
    final count = prefs.getInt(PrefKeys.rateDialogCount) ?? 0;
    if (count >= maxDialogs) return;
    final lastAt = prefs.getInt(PrefKeys.rateDialogLastAt);
    if (lastAt != null && now.difference(DateTime.fromMillisecondsSinceEpoch(lastAt)) < dialogGap) return;

    // Counted before showing: an app closed with the dialog open still counts.
    await prefs.setInt(PrefKeys.rateDialogCount, count + 1);
    await prefs.setInt(PrefKeys.rateDialogLastAt, now.millisecondsSinceEpoch);
    final choice = await ask();
    switch (choice) {
      case RateChoice.rate:
        await prefs.setBool(PrefKeys.rateDone, true);
        await openListing();
      case RateChoice.never:
        await prefs.setBool(PrefKeys.rateDone, true);
      case RateChoice.later:
      case null:
        break;
    }
  }
}
