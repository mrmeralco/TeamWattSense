import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../contracts/repositories.dart';
import '../models/appliance.dart';
import 'sqlite_bill_repository.dart';

class SqliteApplianceRepository implements ApplianceRepository {
  SqliteApplianceRepository(this.database);
  final Database database;

  static Future<SqliteApplianceRepository> open() async {
    final database = await openDatabase(
      p.join(await getDatabasesPath(), 'wattwise.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE appliances (id TEXT PRIMARY KEY, '
          'name TEXT NOT NULL, watts REAL NOT NULL, hours_per_day REAL NOT NULL, '
          'days_per_month INTEGER NOT NULL, quantity INTEGER NOT NULL)',
        );
        await SqliteBillRepository.createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await SqliteBillRepository.createTables(db);
      },
    );
    return SqliteApplianceRepository(database);
  }

  @override
  Future<List<Appliance>> list() async => (await database.query(
        'appliances',
        orderBy: 'name',
      ))
          .map(Appliance.fromMap)
          .toList();
  @override
  Future<void> save(Appliance appliance) async {
    appliance.monthlyKwh; // Validate before persistence.
    await database.insert(
      'appliances',
      appliance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String id) async {
    await database.delete('appliances', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() => database.close();
}
