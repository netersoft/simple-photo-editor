import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_photo_editor/core/helpers/store/store_helper.dart';
import 'package:simple_photo_editor/core/helpers/ui/rate_dialog.dart';
import 'package:simple_photo_editor/core/services/di/locator.dart';
import 'package:simple_photo_editor/core/services/shared_preferences/service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.britannio.in_app_review');

  late SharedPreferencesService prefs;
  late DateTime now;
  late bool available;
  late int requests;
  late int dialogs;
  late int listings;
  RateChoice? choice;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    prefs = (await SharedPreferencesService.getInstance())!;
    await prefs.preferences!.clear();
    locator.registerSingleton<SharedPreferencesService>(prefs);
    now = DateTime(2026, 10, 9);
    StoreHelper.clock = () => now;
    available = true;
    requests = 0;
    dialogs = 0;
    listings = 0;
    choice = RateChoice.later;
    StoreHelper.isAndroid = true;
    StoreHelper.ask = () async {
      dialogs++;
      return choice;
    };
    StoreHelper.openListing = () async => listings++;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return available;
      if (call.method == 'requestReview') requests++;
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    StoreHelper.clock = DateTime.now;
    await locator.unregister<SharedPreferencesService>();
  });

  Future<void> launch(int times) async {
    for (var i = 0; i < times; i++) {
      await StoreHelper.onLaunch();
    }
  }

  test('launching the app never asks for a review', () async {
    await launch(20);
    now = now.add(const Duration(days: 30));
    await launch(1);

    expect(requests, 0);
  });

  test('asks after a saved photo, once the app was opened 3 times over 1 day', () async {
    await launch(3);
    now = now.add(const Duration(days: 1));
    await StoreHelper.onPhotoSaved();

    expect(requests, 1);
  });

  test('waits for 3 launches and 1 day', () async {
    await launch(2);
    now = now.add(const Duration(days: 10));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);

    now = DateTime(2026, 10, 20);
    await prefs.preferences!.clear();
    await launch(10);
    now = now.add(const Duration(hours: 20));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);
  });

  test('asks only once, whatever the number of saved photos', () async {
    await launch(3);
    now = now.add(const Duration(days: 1));
    for (var i = 0; i < 5; i++) {
      await StoreHelper.onPhotoSaved();
    }
    await launch(5);
    await StoreHelper.onPhotoSaved();

    expect(requests, 1);
  });

  test('tries again after the next saved photo when the review flow is not available', () async {
    available = false;
    await launch(3);
    now = now.add(const Duration(days: 1));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);

    available = true;
    await StoreHelper.onPhotoSaved();
    expect(requests, 1);
  });

  /// The sheet was requested, then [days] days went by.
  Future<void> afterSheet(int days) async {
    await launch(3);
    now = now.add(const Duration(days: 1));
    await StoreHelper.onPhotoSaved();
    now = now.add(Duration(days: days));
  }

  test('shows the store dialog only after the delay, then at most 3 times 30 days apart', () async {
    await afterSheet(1);
    await StoreHelper.onPhotoSaved();
    expect(dialogs, 0, reason: 'too soon after the sheet');

    now = now.add(StoreHelper.dialogDelay);
    await StoreHelper.onPhotoSaved();
    expect(dialogs, 1);

    now = now.add(const Duration(days: 10));
    await StoreHelper.onPhotoSaved();
    expect(dialogs, 1, reason: 'too soon after the dialog');

    for (var i = 0; i < 4; i++) {
      now = now.add(StoreHelper.dialogGap);
      await StoreHelper.onPhotoSaved();
    }
    expect(dialogs, StoreHelper.maxDialogs);
    expect(listings, 0);
    expect(requests, 1);
  });

  test('opens the listing and stops asking once the user accepts', () async {
    await afterSheet(StoreHelper.dialogDelay.inDays);
    choice = RateChoice.rate;
    await StoreHelper.onPhotoSaved();
    now = now.add(const Duration(days: 90));
    await StoreHelper.onPhotoSaved();

    expect(dialogs, 1);
    expect(listings, 1);
  });

  test('stops asking once the user opts out', () async {
    await afterSheet(StoreHelper.dialogDelay.inDays);
    choice = RateChoice.never;
    await StoreHelper.onPhotoSaved();
    now = now.add(const Duration(days: 90));
    await StoreHelper.onPhotoSaved();

    expect(dialogs, 1);
    expect(listings, 0);
  });

  test('iOS keeps the system sheet only', () async {
    StoreHelper.isAndroid = false;
    await afterSheet(90);
    await StoreHelper.onPhotoSaved();

    expect(requests, 1);
    expect(dialogs, 0);
  });
}
