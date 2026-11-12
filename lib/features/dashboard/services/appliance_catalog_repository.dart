import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../models/appliance_catalog_item.dart';

class ApplianceCatalogRepository {
  static Future<List<ApplianceCatalogItem>>? _bundledCatalog;

  Future<List<ApplianceCatalogItem>> search(String query) async {
    final terms = _terms(query);
    if (terms.isEmpty || terms.last.length < 2) return const [];

    List<ApplianceCatalogItem> remote = const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('appliance_catalog')
          .where('searchPrefixes', arrayContains: terms.last)
          .limit(60)
          .get();
      remote = snapshot.docs
          .map((doc) => ApplianceCatalogItem.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      // The bundled catalog keeps appliance entry available when Firebase is
      // not configured, offline, or the collection has not been seeded yet.
    }

    final bundled = await (_bundledCatalog ??= _loadBundledCatalog());
    final combined = <String, ApplianceCatalogItem>{
      for (final item in bundled) item.id: item,
      for (final item in remote) item.id: item,
    };
    final matches = combined.values.where((item) {
      final words = _terms(item.searchText);
      return terms.every((term) => words.any((word) => word.startsWith(term)));
    }).toList()
      ..sort((a, b) {
        final aStartsWith = a.name.toLowerCase().startsWith(query.toLowerCase());
        final bStartsWith = b.name.toLowerCase().startsWith(query.toLowerCase());
        if (aStartsWith != bStartsWith) return aStartsWith ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return matches.take(30).toList();
  }

  static Future<List<ApplianceCatalogItem>> _loadBundledCatalog() async {
    final jsonText = await rootBundle.loadString(
      'assets/data/appliance_catalog.json',
    );
    final rows = jsonDecode(jsonText) as List<dynamic>;
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return ApplianceCatalogItem.fromMap(map['id'] as String, map);
    }).toList();
  }

  static List<String> _terms(String text) => RegExp(
        r'[a-z0-9]+(?:[.-][a-z0-9]+)*',
      ).allMatches(text.toLowerCase()).map((match) => match.group(0)!).toList();
}
