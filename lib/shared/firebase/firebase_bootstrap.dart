import 'package:firebase_core/firebase_core.dart';

// Uses the existing iSee project options. Register separate WattWise apps before release.
Future<FirebaseApp> initializeWattWiseFirebase(FirebaseOptions options) =>
    Firebase.initializeApp(options: options);
