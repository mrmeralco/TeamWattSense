import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Debug tokens must be registered for the developer's device in Firebase.
// Release builds always use platform attestation.
Future<FirebaseApp> initializeWattWiseFirebase(FirebaseOptions options) async {
  final app = Firebase.apps.isEmpty
      ? await Firebase.initializeApp(options: options)
      : Firebase.app();
  await FirebaseAppCheck.instanceFor(app: app).activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );
  return app;
}
