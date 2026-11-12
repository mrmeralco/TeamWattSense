import 'package:sqflite/sqflite.dart';

class AiRequestLimit implements Exception {
  const AiRequestLimit(this.message);
  final String message;
}

/// Per-installation guard. Failed attempts count too; reopening does not reset it.
class AiRequestBudget {
  AiRequestBudget(this.database, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final Database database;
  final DateTime Function() clock;
  Future<void> reserve(String feature) async {
    final now = clock();
    final day = '${now.year}-${now.month}-${now.day}';
    await database.transaction((tx) async {
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS ai_request_budget (feature TEXT PRIMARY KEY, day TEXT NOT NULL, count INTEGER NOT NULL, last_ms INTEGER NOT NULL)');
      final rows = await tx.query('ai_request_budget',
          where: 'feature = ?', whereArgs: [feature]);
      final row = rows.isEmpty ? null : rows.single;
      final count = row?['day'] == day ? row!['count'] as int : 0;
      if (row != null &&
          now.millisecondsSinceEpoch - (row['last_ms'] as int) < 10000) {
        throw const AiRequestLimit(
            'Please wait 10 seconds before another AI request.');
      }
      final limit = feature == 'mira' ? 20 : 5;
      if (count >= limit) {
        throw AiRequestLimit(
            'Daily limit reached: $limit ${feature == 'mira' ? 'Mira requests' : 'bill scans'}. Try again tomorrow.');
      }
      await tx.insert(
          'ai_request_budget',
          {
            'feature': feature,
            'day': day,
            'count': count + 1,
            'last_ms': now.millisecondsSinceEpoch
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
