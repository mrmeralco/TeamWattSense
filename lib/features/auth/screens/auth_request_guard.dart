import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const passwordHelp =
    'Use at least 10 characters with an uppercase letter, a number and a special character (for example !, @ or #).';
String? registrationPasswordError(String value) {
  if (value.length < 10 ||
      !RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value) ||
      !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
    return passwordHelp;
  }
  return null;
}

class AuthRequestLimit implements Exception {
  const AuthRequestLimit(this.message);
  final String message;
}

/// Local UX guard, not a substitute for Firebase's server-side abuse controls.
/// Installation-wide counters survive screen changes, sign-out and restart.
class AuthRequestGuard {
  static Future<Database>? _database;
  @visibleForTesting
  static Future<void> Function(String)? testReserve;
  static Future<void> reserve(String action) async {
    if (testReserve != null) return testReserve!(action);
    final db = await (_database ??= _open());
    await reserveIn(db, action, DateTime.now());
  }

  static Future<Database> _open() async {
    try {
      return await openDatabase(
          p.join(await getDatabasesPath(), 'wattwise_request_limits.db'),
          version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE request_limits(action TEXT PRIMARY KEY, started INTEGER NOT NULL, last INTEGER NOT NULL, count INTEGER NOT NULL)');
      });
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  static Future<void> reserveIn(
      Database db, String action, DateTime now) async {
    final (cooldown, limit, window) = switch (action) {
      'register' => (60, 3, 3600),
      'reset' => (60, 5, 3600),
      'verify_send' => (60, 5, 3600),
      'verify_check' => (5, 30, 600),
      'login' => (3, 10, 600),
      _ => throw ArgumentError('Unknown authentication action'),
    };
    await db.transaction((tx) async {
      final rows = await tx
          .query('request_limits', where: 'action=?', whereArgs: [action]);
      final row = rows.isEmpty ? null : rows.single;
      final ms = now.millisecondsSinceEpoch;
      if (row != null && ms - (row['last'] as int) < cooldown * 1000) {
        final wait =
            ((cooldown * 1000 - (ms - (row['last'] as int))) / 1000).ceil();
        throw AuthRequestLimit(
            'Please wait $wait seconds before trying again.');
      }
      final fresh =
          row == null || ms - (row['started'] as int) >= window * 1000;
      final count = fresh ? 0 : row['count'] as int;
      if (count >= limit) {
        throw AuthRequestLimit(
            'Too many attempts. Try again in ${((window * 1000 - (ms - (row!['started'] as int))) / 60000).ceil()} minutes.');
      }
      await tx.insert(
          'request_limits',
          {
            'action': action,
            'started': fresh ? ms : row['started'],
            'last': ms,
            'count': count + 1
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

// Keep the existing registration screen mounted until Firebase's automatic
// sign-in has been signed out and the registration result has been displayed.
bool registrationInProgress = false;
