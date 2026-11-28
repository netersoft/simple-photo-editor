abstract class PrefKeys {
  static const brightness = 'appBrightness';
  static const language = 'appLanguage';
  static const firstOpening = 'appFirstOpening';
  static const firstLaunchDate = 'appFirstLaunchDate';
  static const launchCount = 'appLaunchCount';
  static const reviewRequested = 'appReviewRequested';

  /// When the in-app review sheet was requested (ms since epoch), the store dialog waits after it.
  static const reviewRequestedAt = 'appReviewRequestedAt';

  /// How many times the store dialog was shown, and when last (ms since epoch).
  static const rateDialogCount = 'appRateDialogCount';
  static const rateDialogLastAt = 'appRateDialogLastAt';

  /// The user rated, or asked not to be asked again.
  static const rateDone = 'appRateDone';
}
