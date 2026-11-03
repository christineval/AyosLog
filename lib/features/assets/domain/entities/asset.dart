class Asset {
  const Asset(
      {required this.id,
      required this.name,
      required this.category,
      this.brand = '',
      this.model = '',
      this.archived = false,
      this.legacyCategory,
      this.profiles = const {},
      required this.createdAt});
  final String id, name, category, brand, model;
  final bool archived;
  final String? legacyCategory;
  final Map<String, Map<String, String>> profiles;
  Map<String, String> get setup => profiles[category] ?? const {};
  final DateTime createdAt;
}
