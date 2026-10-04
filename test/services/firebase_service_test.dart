import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_photo_editor/core/services/firebase/service.dart';

void main() {
  test('isConfigured is false with the shipped placeholder options', () {
    expect(FirebaseSetup.isConfigured, isFalse);
  });

  test('ensureInitialized is a no-op when unconfigured', () async {
    await FirebaseSetup.ensureInitialized();

    expect(Firebase.apps, isEmpty);
  });
}
