import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wattwise/shared/sync/sync_store.dart';

Future<SyncStore> device() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
  await db.execute(
      'CREATE TABLE appliances(id TEXT PRIMARY KEY,name TEXT,watts REAL,hours_per_day REAL,days_per_month INTEGER,quantity INTEGER)');
  await db.execute('CREATE TABLE bills(id TEXT PRIMARY KEY,data TEXT)');
  await db.execute(
      'CREATE TABLE daily_usage(appliance_id TEXT,date TEXT,hours REAL,watts REAL,quantity INTEGER,PRIMARY KEY(appliance_id,date))');
  await db.execute('CREATE TABLE preferences(key TEXT PRIMARY KEY,value TEXT)');
  await db.execute(
      'CREATE TABLE pop_transitions(effective_date TEXT PRIMARY KEY,enabled INTEGER,recorded_at TEXT)');
  await db.execute(
      'CREATE TABLE pop_rates(effective_month TEXT PRIMARY KEY,peak_generation_rate REAL,off_peak_generation_rate REAL,source TEXT,is_reference INTEGER,recorded_at TEXT)');
  await db.execute(
      'CREATE TABLE pop_usage_split(appliance_id TEXT,usage_date TEXT,peak_hours REAL,off_peak_hours REAL,PRIMARY KEY(appliance_id,usage_date))');
  await db.execute(
      'CREATE TABLE pop_usage_sessions(appliance_id TEXT,usage_date TEXT,started_at TEXT,stopped_at TEXT,PRIMARY KEY(appliance_id,usage_date))');
  await db.execute(
      'CREATE TABLE kload_profile(id INTEGER PRIMARY KEY,created_at TEXT NOT NULL)');
  await db.execute(
      'CREATE TABLE kload_transitions(effective_date TEXT PRIMARY KEY,enabled INTEGER NOT NULL,recorded_at TEXT NOT NULL)');
  await db.execute(
      'CREATE TABLE kload_rates(effective_date TEXT PRIMARY KEY,rate_per_kwh REAL NOT NULL,source TEXT NOT NULL,recorded_at TEXT NOT NULL)');
  await db.execute(
      'CREATE TABLE kload_balance_events(id TEXT PRIMARY KEY,event_date TEXT NOT NULL,event_type TEXT NOT NULL,amount REAL NOT NULL,note TEXT NOT NULL,recorded_at TEXT NOT NULL)');
  return SyncStore(db);
}

const fan = {
  'id': 'fan:1',
  'name': 'Fan',
  'watts': 60.0,
  'hours_per_day': 8.0,
  'days_per_month': 30,
  'quantity': 2
};
Future<void> transfer(SyncStore a, SyncStore b) async {
  for (final item in await a.pending()) {
    await b.apply(item);
    await a.acknowledge(item);
  }
}

void main() {
  test(
      'Two devices restore appliances bills images usage and deletions without echo',
      () async {
    final a = await device(), b = await device();
    await a.initialize();
    await b.initialize();
    await a.db.insert('appliances', fan);
    final image = base64Encode(List.generate(1200000, (i) => i % 256));
    await a.db.insert('bills', {
      'id': 'bill',
      'data': jsonEncode({'sourceImage': image, 'consumptionKwh': 600})
    });
    await a.db.insert('daily_usage', {
      'appliance_id': 'fan:1',
      'date': '2026-11-12',
      'hours': 3.0,
      'watts': 60.0,
      'quantity': 2
    });
    await a.db.insert('pop_usage_sessions', {
      'appliance_id': 'fan:1',
      'usage_date': '2026-11-12',
      'started_at': '2026-11-12T10:00:00',
      'stopped_at': '2026-11-12T13:00:00'
    });
    await transfer(a, b);
    expect((await b.db.query('appliances')).single['quantity'], 2);
    expect(
        jsonDecode((await b.db.query('bills')).single['data'] as String)[
            'sourceImage'],
        image);
    expect((await b.db.query('daily_usage')).single['hours'], 3.0);
    expect((await b.db.query('pop_usage_sessions')).length, 1);
    expect(await b.count(), 0);
    await a.db.delete('appliances', where: 'id=?', whereArgs: ['fan:1']);
    await a.db.delete('bills');
    await transfer(a, b);
    expect(await b.db.query('appliances'), isEmpty);
    expect(await b.db.query('bills'), isEmpty);
    await a.db.close();
    await b.db.close();
  });
  test(
      'Local pending edits survive pull, recreation and acknowledgement of an older revision',
      () async {
    final a = await device(), b = await device();
    await a.initialize();
    await b.initialize();
    await a.db.insert('appliances', fan);
    final first = (await a.pending()).single;
    await b.apply(first);
    await a.acknowledge(first);
    await a.db.update('appliances', {'name': 'Local edit'});
    final pending = (await a.pending()).single;
    await b.db.update('appliances', {'name': 'Remote edit'});
    expect(await a.apply((await b.pending()).single), false);
    final reopened = SyncStore(a.db);
    await reopened.initialize();
    expect(await reopened.count(), 1);
    await a.db.update('appliances', {'name': 'Newer local edit'});
    await a.acknowledge(pending);
    expect(await a.count(), 1);
    expect((await a.pending()).single.row!['name'], 'Newer local edit');
    await a.db.close();
    await b.db.close();
  });
  test(
      'Initial migration yields to cloud copies and excludes private local preferences',
      () async {
    final old = await device(), cloud = await device();
    await cloud.initialize();
    await old.db.insert('appliances', fan);
    await old.db.insert(
        'preferences', {'key': 'accepted_policy_version', 'value': 'local'});
    await old.db.insert('preferences', {'key': 'ai_mira_count', 'value': '10'});
    await old.db.insert('preferences', {'key': 'language', 'value': 'fil'});
    await old.initialize();
    expect(await old.count(), 2);
    await cloud.db.insert('appliances', {...fan, 'name': 'Cloud copy'});
    await old.apply((await cloud.pending()).single);
    expect((await old.db.query('appliances')).single['name'], 'Cloud copy');
    expect((await old.pending()).single.table, 'preferences');
    await old.db.insert('preferences', {'key': 'rate', 'value': '13'});
    expect(await old.count(), 2);
    await old.db.close();
    await cloud.db.close();
  });
}
