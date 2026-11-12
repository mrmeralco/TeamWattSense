import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../contracts/repositories.dart';
import '../models/bill.dart';

class SqliteBillRepository implements BillRepository {
  const SqliteBillRepository(this.database);
  final Database database;
  static Future<void> createTables(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS bills (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  @override
  Future<List<Bill>> list() async => (await database.query('bills')).map((row) {
        final m = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        return Bill(
            id: row['id'] as String,
            periodEnd: DateTime.parse(m['periodEnd']),
            dueDate: DateTime.parse(m['dueDate']),
            consumptionKwh: (m['consumptionKwh'] as num).toDouble(),
            totalAmount: (m['totalAmount'] as num).toDouble(),
            reviewed: m['reviewed'] == true,
            sourceName: m['sourceName'],
            sourceImage: m['sourceImage'] == null
                ? null
                : base64Decode(m['sourceImage']),
            ratePerKwh: (m['ratePerKwh'] as num?)?.toDouble(),
            insights: m['insights'] as String?,
            savingsInsight: m['savingsInsight'] as String?,
            charges: (m['charges'] as List)
                .map((c) => BillCharge(
                    name: c['name'],
                    amount: (c['amount'] as num).toDouble(),
                    explanation: c['explanation']))
                .toList());
      }).toList()
        ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
  @override
  Future<Bill?> latestReviewed() async {
    final bills = (await list()).where((b) => b.reviewed);
    return bills.isEmpty ? null : bills.first;
  }

  @override
  Future<void> save(Bill bill) async {
    if (!bill.totalAmount.isFinite ||
        bill.totalAmount < 0 ||
        !bill.consumptionKwh.isFinite ||
        bill.consumptionKwh < 0 ||
        bill.charges.any((c) => !c.amount.isFinite)) {
      throw ArgumentError('Invalid bill values');
    }
    await database.insert(
        'bills',
        {
          'id': bill.id,
          'data': jsonEncode({
            'periodEnd': bill.periodEnd.toIso8601String(),
            'dueDate': bill.dueDate.toIso8601String(),
            'consumptionKwh': bill.consumptionKwh,
            'totalAmount': bill.totalAmount,
            'reviewed': bill.reviewed,
            'sourceName': bill.sourceName,
            'sourceImage': bill.sourceImage == null
                ? null
                : base64Encode(bill.sourceImage!),
            'ratePerKwh': bill.effectiveRatePerKwh,
            'insights': bill.insights,
            'savingsInsight': bill.savingsInsight,
            'charges': bill.charges
                .map((c) => {
                      'name': c.name,
                      'amount': c.amount,
                      'explanation': c.explanation
                    })
                .toList()
          })
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(String id) async {
    await database.delete('bills', where: 'id = ?', whereArgs: [id]);
  }
}
