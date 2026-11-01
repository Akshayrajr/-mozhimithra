import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

const firebaseEmulatorHostOverride = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
);

const firebaseAuthEmulatorPort = 9099;
const firebaseFunctionsEmulatorPort = 5001;
const firebaseFirestoreEmulatorPort = 8080;
const firebaseStorageEmulatorPort = 9199;

String firebaseEmulatorHost({
  required bool isWeb,
  required TargetPlatform platform,
  String? override,
}) {
  final configuredHost = override?.trim();
  if (configuredHost != null && configuredHost.isNotEmpty) {
    return configuredHost;
  }
  if (isWeb) return 'localhost';
  return platform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
}

Future<void> configureFirebaseEmulators() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    throw UnsupportedError(
      'Firebase Storage emulation is unavailable on Windows desktop. '
      'Run the app on Chrome or an Android emulator instead.',
    );
  }
  final host = firebaseEmulatorHost(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    override: firebaseEmulatorHostOverride,
  );
  final app = Firebase.app();

  await FirebaseAuth.instance.useAuthEmulator(host, firebaseAuthEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(
    host,
    firebaseFirestoreEmulatorPort,
  );
  await FirebaseStorage.instanceFor(
    app: app,
  ).useStorageEmulator(host, firebaseStorageEmulatorPort);
  FirebaseFunctions.instanceFor(
    app: app,
    region: 'asia-south1',
  ).useFunctionsEmulator(host, firebaseFunctionsEmulatorPort);
}
