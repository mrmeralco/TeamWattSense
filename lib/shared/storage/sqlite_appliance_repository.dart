import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../contracts/repositories.dart';
import '../models/appliance.dart';
import '../models/daily_usage.dart';
import 'sqlite_bill_repository.dart';

class SqliteApplianceRepository implements ApplianceRepository {
  SqliteApplianceRepository(this.database);
  final Database database;

  static String databaseNameForUser(String uid) {
    if (uid.isEmpty || utf8.encode(uid).length > 128) {
      throw ArgumentError('Invalid account ID');
    }
    return 'wattwise_user_${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}.db';
  }

  static Future<SqliteApplianceRepository> open({String? userId}) async {
    final database = await openDatabase(
      p.join(await getDatabasesPath(),
          userId == null ? 'wattwise.db' : databaseNameForUser(userId)),
      version: 8,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE appliances (id TEXT PRIMARY KEY, '
          'name TEXT NOT NULL, watts REAL NOT NULL, hours_per_day REAL NOT NULL, '
          'days_per_month INTEGER NOT NULL, quantity INTEGER NOT NULL)',
        );
        await SqliteBillRepository.createTables(db);
        await db.execute(
          'CREATE TABLE daily_usage (appliance_id TEXT NOT NULL, date TEXT NOT NULL, '
          'hours REAL NOT NULL, watts REAL NOT NULL, quantity INTEGER NOT NULL, '
          'PRIMARY KEY (appliance_id, date))',
        );
        await _createPopTables(db);
        await _createPopSessionTable(db);
        await _createKLoadTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await SqliteBillRepository.createTables(db);
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE daily_usage (appliance_id TEXT NOT NULL, date TEXT NOT NULL, '
            'hours REAL NOT NULL, PRIMARY KEY (appliance_id, date))',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE daily_usage ADD COLUMN watts REAL NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE daily_usage ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1');
          await db.execute(
              'UPDATE daily_usage SET watts = COALESCE((SELECT watts FROM appliances WHERE appliances.id = daily_usage.appliance_id), 0), '
              'quantity = COALESCE((SELECT quantity FROM appliances WHERE appliances.id = daily_usage.appliance_id), 1)');
        }
        if (oldVersion < 5) await _createPopTables(db);
        if (oldVersion < 6) await _createPopSessionTable(db);
        // Repeat creation idempotently for databases that reached version 7
        // before the KLoad tables were present in every installed build.
        if (oldVersion < 8) await _createKLoadTables(db);
      },
    );
    return SqliteApplianceRepository(database);
  }

  static Future<void> _createPopTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pop_transitions (
        effective_date TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pop_rates (
        effective_month TEXT PRIMARY KEY,
        peak_generation_rate REAL NOT NULL CHECK (peak_generation_rate >= 0),
        off_peak_generation_rate REAL NOT NULL CHECK (off_peak_generation_rate >= 0),
        source TEXT NOT NULL,
        is_reference INTEGER NOT NULL DEFAULT 0 CHECK (is_reference IN (0, 1)),
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pop_usage_split (
        appliance_id TEXT NOT NULL,
        usage_date TEXT NOT NULL,
        peak_hours REAL NOT NULL CHECK (peak_hours >= 0),
        off_peak_hours REAL NOT NULL CHECK (off_peak_hours >= 0),
        PRIMARY KEY (appliance_id, usage_date),
        CHECK (peak_hours + off_peak_hours <= 24)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pop_usage_split_date
      ON pop_usage_split (usage_date)
    ''');
  }

  static Future<void> _createPopSessionTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pop_usage_sessions (
        appliance_id TEXT NOT NULL,
        usage_date TEXT NOT NULL,
        started_at TEXT NOT NULL,
        stopped_at TEXT NOT NULL,
        PRIMARY KEY (appliance_id, usage_date),
        CHECK (stopped_at > started_at)
      )
    ''');
  }

  static Future<void> _createKLoadTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kload_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kload_transitions (
        effective_date TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kload_rates (
        effective_date TEXT PRIMARY KEY,
        rate_per_kwh REAL NOT NULL CHECK (rate_per_kwh >= 0),
        source TEXT NOT NULL,
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kload_balance_events (
        id TEXT PRIMARY KEY,
        event_date TEXT NOT NULL,
        event_type TEXT NOT NULL CHECK (event_type IN ('initial', 'top_up', 'adjustment')),
        amount REAL NOT NULL,
        note TEXT NOT NULL,
        recorded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_kload_balance_events_date
      ON kload_balance_events (event_date)
    ''');
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
    await database
        .delete('daily_usage', where: 'appliance_id = ?', whereArgs: [id]);
  }

  Future<void> close() => database.close();
}

class SqliteDailyUsageRepository implements DailyUsageRepository {
  const SqliteDailyUsageRepository(this.database);
  final Database database;

  @override
  Future<List<DailyUsage>> list({DateTime? from, DateTime? through}) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('date >= ?');
      args.add(_key(from));
    }
    if (through != null) {
      clauses.add('date <= ?');
      args.add(_key(through));
    }
    final rows = await database.query('daily_usage',
        where: clauses.isEmpty ? null : clauses.join(' AND '),
        whereArgs: clauses.isEmpty ? null : args,
        orderBy: 'date, appliance_id');
    return rows
        .map((row) => DailyUsage(
              applianceId: row['appliance_id'] as String,
              date: DateTime.parse(row['date'] as String),
              hours: (row['hours'] as num).toDouble(),
              watts: (row['watts'] as num).toDouble(),
              quantity: row['quantity'] as int,
            ))
        .toList();
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Future<void> saveAll(List<DailyUsage> entries) async {
    for (final entry in entries) {
      if (!entry.hours.isFinite || entry.hours < 0 || entry.hours > 24) {
        throw ArgumentError('Daily usage must be between 0 and 24 hours');
      }
      if (!entry.watts.isFinite || entry.watts < 0 || entry.quantity < 1) {
        throw ArgumentError('Invalid appliance details for daily usage');
      }
    }
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in entries) {
        batch.insert(
            'daily_usage',
            {
              'appliance_id': entry.applianceId,
              'date': entry.dateKey,
              'hours': entry.hours,
              'watts': entry.watts,
              'quantity': entry.quantity,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> removeForDate(String applianceId, DateTime date) async {
    await database.transaction((txn) async {
      await txn.delete('daily_usage',
          where: 'appliance_id = ? AND date = ?',
          whereArgs: [applianceId, _key(date)]);
      for (final table in ['pop_usage_split', 'pop_usage_sessions']) {
        await txn.delete(table,
            where: 'appliance_id = ? AND usage_date = ?',
            whereArgs: [applianceId, _key(date)]);
      }
    });
  }

  @override
  Future<void> removeForAppliance(String applianceId) async {
    await database.delete('daily_usage',
        where: 'appliance_id = ?', whereArgs: [applianceId]);
  }
}
