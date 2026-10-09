import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_photo_editor/core/helpers/store/store_helper.dart';
import 'package:simple_photo_editor/core/services/di/locator.dart';
import 'package:simple_photo_editor/core/services/shared_preferences/service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.britannio.in_app_review');

  late SharedPreferencesService prefs;
  late DateTime now;
  late bool available;
  late int requests;

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    prefs = (await SharedPreferencesService.getInstance())!;
    await prefs.preferences!.clear();
    locator.registerSingleton<SharedPreferencesService>(prefs);
    now = DateTime(2026, 10, 9);
    StoreHelper.clock = () => now;
    available = true;
    requests = 0;
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

  test('asks after a saved photo, once the app was opened 5 times over 3 days', () async {
    await launch(5);
    now = now.add(const Duration(days: 3));
    await StoreHelper.onPhotoSaved();

    expect(requests, 1);
  });

  test('waits for 5 launches and 3 days', () async {
    await launch(4);
    now = now.add(const Duration(days: 10));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);

    now = DateTime(2026, 10, 20);
    await prefs.preferences!.clear();
    await launch(10);
    now = now.add(const Duration(days: 2));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);
  });

  test('asks only once, whatever the number of saved photos', () async {
    await launch(5);
    now = now.add(const Duration(days: 3));
    for (var i = 0; i < 5; i++) {
      await StoreHelper.onPhotoSaved();
    }
    await launch(5);
    await StoreHelper.onPhotoSaved();

    expect(requests, 1);
  });

  test('tries again after the next saved photo when the review flow is not available', () async {
    available = false;
    await launch(5);
    now = now.add(const Duration(days: 3));
    await StoreHelper.onPhotoSaved();
    expect(requests, 0);

    available = true;
    await StoreHelper.onPhotoSaved();
    expect(requests, 1);
  });
}
