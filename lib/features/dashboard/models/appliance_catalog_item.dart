class ApplianceCatalogItem {
  const ApplianceCatalogItem({
    required this.id,
    required this.name,
    required this.searchText,
    required this.searchPrefixes,
    this.watts,
    this.category = '',
    this.sku = '',
  });

  static const customId = '__custom_appliance__';

  final String id;
  final String name;
  final String searchText;
  final List<String> searchPrefixes;
  final double? watts;
  final String category;
  final String sku;

  bool get isCustom => id == customId;

  factory ApplianceCatalogItem.fromMap(
      String id, Map<String, dynamic> map) {
    final rawWatts = map['watts'];
    final rawPrefixes = map['searchPrefixes'];
    return ApplianceCatalogItem(
      id: id,
      name: map['name'] as String? ?? '',
      searchText: map['searchText'] as String? ?? map['name'] as String? ?? '',
      searchPrefixes: rawPrefixes is Iterable
          ? rawPrefixes.whereType<String>().toList()
          : const [],
      watts: rawWatts is num ? rawWatts.toDouble() : null,
      category: map['category'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
    );
  }

  factory ApplianceCatalogItem.custom(String name) => ApplianceCatalogItem(
        id: customId,
        name: name,
        searchText: name.toLowerCase(),
        searchPrefixes: const [],
      );
}
