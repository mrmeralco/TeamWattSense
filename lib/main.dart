import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'shared/firebase/firebase_bootstrap.dart';
import 'features/auth/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final app = await initializeWattWiseFirebase(
        DefaultFirebaseOptions.currentPlatform);
    runApp(AuthGate(app: app));
  } catch (_) {
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
          'WattWise could not start account services. Your saved data is unchanged.'),
      TextButton(onPressed: main, child: const Text('Retry')),
    ])))));
  }
}
