/// Canonical keys from CATEGORY_FORMS.md. Stored keys never depend on labels.
enum AssetCategory {
  vehicle('vehicle', 'Vehicle / Motorcycle', 'vehicle'),
  airConditioner('air_conditioner', 'Air Conditioner', 'airConditioner'),
  refrigerator('refrigerator', 'Refrigerator / Freezer', 'refrigerator'),
  laptop('laptop', 'Laptop / Electronics', 'laptop'),
  waterFilter('water_filter', 'Water Filter / Purifier', 'waterFilter'),
  washingMachine('washing_machine', 'Washing Machine', 'washingMachine'),
  custom('custom', 'Custom / Other', 'custom');

  const AssetCategory(this.key, this.label, this.subtypeKey);
  final String key, label, subtypeKey;
  static AssetCategory? fromKey(String key) =>
      values.where((c) => c.key == key).firstOrNull;
  static String labelFor(String key) => fromKey(key)?.label ?? key;
}
