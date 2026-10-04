import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simple_photo_editor/core/enums/app_brightness.dart';
import 'package:simple_photo_editor/core/providers/navigation/redirection_provider.dart';
import 'package:simple_photo_editor/core/routes/app_route.dart';
import 'package:simple_photo_editor/core/services/shared_preferences/keys.dart';

import '../helpers/test_utils.dart';

/// Runs [Redirection.redirect] with a real [WidgetRef] it doesn't use.
Future<void> _redirect(WidgetTester tester) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        },
      ),
    ),
  );
  await ref.read(redirectionProvider.notifier).redirect(ref);
}

void main() {
  late MockSharedPreferencesService prefs;
  late MockNavigationHelper navigation;

  setUp(() async {
    prefs = MockSharedPreferencesService();
    navigation = MockNavigationHelper();
    when(() => navigation.navigatorKey).thenReturn(GlobalKey<NavigatorState>());
    when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => prefs.setString(any(), any())).thenAnswer((_) async => true);
    await setupTestLocator(sharedPreferencesService: prefs, navigationHelper: navigation);
  });

  tearDown(teardownTestLocator);

  testWidgets('the first opening stores the defaults, then goes to the home screen', (tester) async {
    when(() => prefs.getBool(PrefKeys.firstOpening, defaultValue: true)).thenReturn(true);

    await _redirect(tester);

    verify(() => prefs.setBool(PrefKeys.firstOpening, false)).called(1);
    verify(() => prefs.setString(PrefKeys.brightness, AppBrightness.system.name)).called(1);
    verify(() => navigation.pushReplacement(const MainRoute().location)).called(1);
  });

  testWidgets('later openings go straight to the home screen', (tester) async {
    when(() => prefs.getBool(PrefKeys.firstOpening, defaultValue: true)).thenReturn(false);

    await _redirect(tester);

    verifyNever(() => prefs.setBool(any(), any()));
    verify(() => navigation.pushReplacement(const MainRoute().location)).called(1);
  });
}
