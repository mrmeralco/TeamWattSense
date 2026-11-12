import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sync_store.dart';

/// SQLite is authoritative for pending offline edits. Server commit order
/// resolves simultaneous edits to the same record; deletes are tombstones.
class CloudSync {
  CloudSync(
      {required this.store,
      required this.firestore,
      required this.auth,
      required this.uid,
      required this.onChanged,
      required this.onStatus});
  final SyncStore store;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final String uid;
  final Future<void> Function() onChanged;
  final void Function(String) onStatus;
  Timer? _timer;
  Future<void>? _running;
  bool _stopped = false;
  Timestamp? _cursor;
  CollectionReference<Map<String, dynamic>> get records =>
      firestore.collection('wattwise_users').doc(uid).collection('records');
  bool get active =>
      !_stopped &&
      auth.currentUser?.uid == uid &&
      auth.currentUser?.emailVerified == true;
  Future<void> start() async {
    await store.initialize();
    if (!active) return;
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => unawaited(sync()));
    unawaited(sync());
  }

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    await _running;
  }

  Future<void> sync() {
    if (!active) return Future.value();
    return _running ??= _cycle().whenComplete(() => _running = null);
  }

  void status(String value) {
    if (active) onStatus(value);
  }

  Future<SyncRecord> decode(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final m = doc.data()!;
    if (m['schema'] != 1) {
      throw const FormatException('Unsupported cloud schema');
    }
    String payload = m['payload'] as String;
    final count = m['parts'] as int;
    if (count < 0 || count > 400) {
      throw const FormatException('Invalid cloud image');
    }
    if (count > 0) {
      final pieces = <String>[];
      for (var i = 0; i < count; i++) {
        final part = await doc.reference
            .collection('parts')
            .doc('${m['version']}_$i')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15));
        if (!part.exists) throw const FormatException('Incomplete cloud image');
        pieces.add(part.data()!['payload'] as String);
      }
      payload = pieces.join();
    }
    return SyncRecord(
        m['table'] as String,
        m['key'] as String,
        m['version'] as String,
        m['deleted'] == true
            ? null
            : Map<String, Object?>.from(
                jsonDecode(utf8.decode(base64Decode(payload))) as Map));
  }

  Future<void> _cycle() async {
    var changed = false;
    try {
      status('Syncing your account…');
      Query<Map<String, dynamic>> query = records;
      if (_cursor != null) {
        query = query.where('updatedAt', isGreaterThanOrEqualTo: _cursor);
      }
      final remote = await query
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      Timestamp? next = _cursor;
      for (final doc in remote.docs) {
        if (!active) return;
        // Do not redownload bill images for unchanged manifests.
        final m = doc.data();
        final seen = await store.db.query('sync_seen',
            where: 'tbl=? AND record_key=? AND version=?',
            whereArgs: [m['table'], m['key'], m['version']]);
        if (seen.isEmpty) {
          changed = await store.apply(await decode(doc)) || changed;
        }
        final stamp = m['updatedAt'] as Timestamp;
        if (next == null || stamp.compareTo(next) > 0) next = stamp;
      }
      // Persisted outbox survives restarts. Seed records never replace cloud data.
      final queued = await store.pending();
      for (final record in queued) {
        if (!active) return;
        final doc = records.doc(record.id);
        final payload = record.row == null
            ? ''
            : base64Encode(utf8.encode(jsonEncode(record.row)));
        const size = 180000;
        final count =
            payload.length > size ? (payload.length / size).ceil() : 0;
        if (count > 400) {
          throw const FormatException('Record too large to sync');
        }
        for (var i = 0; i < count; i++) {
          if (!active) return;
          final end =
              (i + 1) * size < payload.length ? (i + 1) * size : payload.length;
          await doc
              .collection('parts')
              .doc('${record.version}_$i')
              .set({'payload': payload.substring(i * size, end)}).timeout(
                  const Duration(seconds: 15));
        }
        if (!active) return;
        final existing =
            await firestore.runTransaction<Map<String, dynamic>?>((tx) async {
          if (!active) throw StateError('Account changed');
          final old = await tx.get(doc);
          if (record.seed && old.exists) return {'retained': true};
          tx.set(doc, {
            'schema': 1,
            'table': record.table,
            'key': record.key,
            'version': record.version,
            'deleted': record.row == null,
            'payload': count == 0 ? payload : '',
            'parts': count,
            'updatedAt': FieldValue.serverTimestamp()
          });
          return {'retained': false, 'old': old.data()};
        }, timeout: const Duration(seconds: 15));
        if (!active) return;
        if (existing?['retained'] != true) {
          await store.acknowledge(record);
          final old = existing?['old'] as Map<String, dynamic>?;
          if (old != null &&
              old['version'] != record.version &&
              (old['parts'] as int? ?? 0) > 0 &&
              active) {
            final cleanup = firestore.batch();
            for (var i = 0; i < (old['parts'] as int); i++) {
              cleanup
                  .delete(doc.collection('parts').doc('${old['version']}_$i'));
            }
            await cleanup.commit().timeout(const Duration(seconds: 15));
          }
        } else {
          changed = await store.apply(await decode(
                  await doc.get(const GetOptions(source: Source.server)))) ||
              changed;
        }
      }
      if (!active) return;
      _cursor = next;
      final pending = await store.count();
      status(pending == 0
          ? 'Cloud sync up to date'
          : '$pending changes waiting to sync');
    } catch (error) {
      status(error is FirebaseException && error.code == 'permission-denied'
          ? 'Cloud access unavailable. Your changes remain saved on this device. Tap Sync now to retry.'
          : 'Waiting to sync. Your changes remain saved on this device. Check your connection and tap Sync now.');
    } finally {
      if (changed && active) {
        try {
          await onChanged();
        } catch (_) {
          status(
              'Cloud data was saved locally. Reopen the app to refresh your records.');
        }
      }
    }
  }
}
