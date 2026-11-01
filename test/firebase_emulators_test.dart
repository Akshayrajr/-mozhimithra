import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learno/firebase_emulators.dart';

void main() {
  test('uses the Android emulator host for Android devices', () {
    expect(
      firebaseEmulatorHost(isWeb: false, platform: TargetPlatform.android),
      '10.0.2.2',
    );
  });

  test('uses localhost for web and desktop', () {
    expect(
      firebaseEmulatorHost(isWeb: true, platform: TargetPlatform.android),
      'localhost',
    );
    expect(
      firebaseEmulatorHost(isWeb: false, platform: TargetPlatform.windows),
      'localhost',
    );
  });

  test('uses an explicitly configured reachable host', () {
    expect(
      firebaseEmulatorHost(
        isWeb: false,
        platform: TargetPlatform.android,
        override: ' 192.168.1.10 ',
      ),
      '192.168.1.10',
    );
  });
}
