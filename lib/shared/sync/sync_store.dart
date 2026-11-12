import 'dart:convert';
import 'package:sqflite/sqflite.dart';

const syncKeys = <String, List<String>>{
  'appliances': ['id'],
  'bills': ['id'],
  'daily_usage': ['appliance_id', 'date'],
  'preferences': ['key'],
  'pop_transitions': ['effective_date'],
  'pop_rates': ['effective_month'],
  'pop_usage_split': ['appliance_id', 'usage_date'],
  'pop_usage_sessions': ['appliance_id', 'usage_date'],
};
const syncPreferences = ['dark', 'language', 'rate', 'pop'];

class SyncRecord {
  const SyncRecord(this.table, this.key, this.version, this.row,
      {this.seed = false});
  final String table, key, version;
  final Map<String, Object?>? row;
  final bool seed;
  String get id =>
      base64Url.encode(utf8.encode('$table:$key')).replaceAll('=', '');
}

class SyncStore {
  SyncStore(this.db);
  final Database db;
  Future<void> initialize() async {
    await db.transaction((tx) async {
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS sync_control (id INTEGER PRIMARY KEY, applying INTEGER NOT NULL)');
      await tx.execute('INSERT OR IGNORE INTO sync_control VALUES (1,0)');
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS sync_outbox (tbl TEXT NOT NULL, record_key TEXT NOT NULL, version TEXT NOT NULL, seed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(tbl,record_key))');
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS sync_seen (tbl TEXT NOT NULL, record_key TEXT NOT NULL, version TEXT NOT NULL, PRIMARY KEY(tbl,record_key))');
      await tx.execute(
          'CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      for (final entry in syncKeys.entries) {
        final table = entry.key;
        for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
          final alias = op == 'DELETE' ? 'OLD' : 'NEW';
          final key = entry.value
              .map((k) => 'hex(CAST($alias.$k AS BLOB))')
              .join(" || ':' || ");
          final filter = table == 'preferences'
              ? " AND $alias.key IN ('dark','language','rate','pop')"
              : '';
          await tx.execute(
              'CREATE TRIGGER IF NOT EXISTS sync_${table}_${op.toLowerCase()} AFTER $op ON $table WHEN (SELECT applying FROM sync_control WHERE id=1)=0$filter BEGIN INSERT OR REPLACE INTO sync_outbox(tbl,record_key,version,seed) VALUES (\'$table\',$key,lower(hex(randomblob(16))),0); END');
        }
      }
      final ready =
          await tx.query('sync_meta', where: 'key=?', whereArgs: ['seeded']);
      if (ready.isEmpty) {
        for (final entry in syncKeys.entries) {
          final key = entry.value
              .map((k) => 'hex(CAST($k AS BLOB))')
              .join(" || ':' || ");
          final filter = entry.key == 'preferences'
              ? " WHERE key IN ('dark','language','rate','pop')"
              : '';
          await tx.execute(
              'INSERT OR IGNORE INTO sync_outbox(tbl,record_key,version,seed) SELECT \'${entry.key}\',$key,lower(hex(randomblob(16))),1 FROM ${entry.key}$filter');
        }
        await tx.insert('sync_meta', {'key': 'seeded', 'value': '1'});
      }
    });
  }

  List<String> values(String key) => key
      .split(':')
      .map((s) => utf8.decode([
            for (var i = 0; i < s.length; i += 2)
              int.parse(s.substring(i, i + 2), radix: 16)
          ]))
      .toList();
  String where(String table) =>
      syncKeys[table]!.map((k) => '$k = ?').join(' AND ');
  Future<List<SyncRecord>> pending() => db.transaction((tx) async {
        final queued = await tx.query('sync_outbox');
        final result = <SyncRecord>[];
        for (final item in queued) {
          final table = item['tbl'] as String,
              key = item['record_key'] as String;
          final rows = await tx.query(table,
              where: where(table), whereArgs: values(key));
          result.add(SyncRecord(table, key, item['version'] as String,
              rows.isEmpty ? null : rows.single,
              seed: item['seed'] == 1));
        }
        return result;
      });
  Future<int> count() async =>
      Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_outbox')) ??
      0;
  Future<void> acknowledge(SyncRecord record) async {
    await db.transaction((tx) async {
      await tx.delete('sync_outbox',
          where: 'tbl=? AND record_key=? AND version=?',
          whereArgs: [record.table, record.key, record.version]);
      await tx.insert(
          'sync_seen',
          {
            'tbl': record.table,
            'record_key': record.key,
            'version': record.version
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<bool> apply(SyncRecord record) async {
    if (!syncKeys.containsKey(record.table)) {
      throw const FormatException('Unknown cloud record');
    }
    final keyValues = values(record.key);
    if (keyValues.length != syncKeys[record.table]!.length) {
      throw const FormatException('Invalid record key');
    }
    if (record.table == 'preferences' &&
        !syncPreferences.contains(keyValues.single)) {
      throw const FormatException('Private preference cannot sync');
    }
    if (record.row != null) {
      for (var i = 0; i < keyValues.length; i++) {
        if (record.row![syncKeys[record.table]![i]].toString() != keyValues[i]) {
          throw const FormatException('Mismatched cloud record');
        }
      }
    }
    return db.transaction((tx) async {
      final queued = await tx.query('sync_outbox',
          where: 'tbl=? AND record_key=?',
          whereArgs: [record.table, record.key]);
      if (queued.isNotEmpty && queued.single['seed'] == 0) return false;
      final seen = await tx.query('sync_seen',
          where: 'tbl=? AND record_key=?',
          whereArgs: [record.table, record.key]);
      if (seen.isNotEmpty && seen.single['version'] == record.version) {
        return false;
      }
      await tx.update('sync_control', {'applying': 1}, where: 'id=1');
      if (record.row == null) {
        await tx.delete(record.table,
            where: where(record.table), whereArgs: keyValues);
      } else {
        await tx.insert(record.table, record.row!,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.delete('sync_outbox',
          where: 'tbl=? AND record_key=?',
          whereArgs: [record.table, record.key]);
      await tx.insert(
          'sync_seen',
          {
            'tbl': record.table,
            'record_key': record.key,
            'version': record.version
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.update('sync_control', {'applying': 0}, where: 'id=1');
      return true;
    });
  }
}
