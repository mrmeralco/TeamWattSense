import 'package:flutter/material.dart';
import 'app/app_controller.dart';
import 'app/wattwise_app.dart';
import 'firebase_options.dart';
import 'shared/firebase/firebase_bootstrap.dart';
import 'shared/storage/sqlite_appliance_repository.dart';
import 'shared/storage/sqlite_bill_repository.dart';
import 'features/mira/services/mira_context_provider.dart';
import 'features/mira/services/firebase_mira_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Offline data is available even when Firebase initialization fails.
    final appliances = await SqliteApplianceRepository.open();
    final bills = SqliteBillRepository(appliances.database);
    final dailyUsage = SqliteDailyUsageRepository(appliances.database);
    final controller = AppController(
        applianceRepository: appliances,
        billRepository: bills,
        dailyUsageRepository: dailyUsage,
        database: appliances.database);
    await controller.load();
    FirebaseMiraService? mira;
    String? error;
    try {
      final app = await initializeWattWiseFirebase(
              DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 12));
      mira = FirebaseMiraService(app, MiraContextProvider(appliances, bills));
    } catch (_) {
      error =
          'Mira is unavailable. Your appliances and bills still work offline. Check your connection and Firebase configuration.';
    }
    runApp(WattWiseApp(controller: controller, mira: mira, miraError: error));
  } catch (_) {
    runApp(MaterialApp(
        home: Scaffold(
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'WattWise could not open local storage. Your saved data has not been replaced.'),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: main, child: const Text('Retry'))
                    ]))))));
  }
}
