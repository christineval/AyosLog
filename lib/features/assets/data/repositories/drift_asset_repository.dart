import 'package:drift/drift.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/asset.dart' as domain;
import '../../domain/repositories/asset_repository.dart';
import '../../domain/entities/asset_category.dart';
import '../../domain/usecases/create_asset.dart';
import '../../../predictions/data/forecast_local_store.dart';

class DriftAssetRepository implements AssetRepository {
  const DriftAssetRepository(this.db);
  final AppDatabase db;
  domain.Asset _map(Asset row,
          [List<StoredAssetProfile> profiles = const []]) =>
      domain.Asset(
          id: row.id,
          name: row.name,
          category: row.category,
          brand: row.brand,
          model: row.model,
          archived: row.archived,
          legacyCategory: row.legacyCategory,
          profiles: {
            for (final p in profiles) p.category: _decodeSetup(p.detailsJson)
          },
          createdAt: row.createdAt);
  Map<String, String> _decodeSetup(String json) {
    try {
      return Map<String, String>.from(jsonDecode(json) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  @override
  Stream<List<domain.Asset>> watchAssets() => (db.select(db.assets)
        ..where((a) => a.archived.equals(false))
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
      .join([
        leftOuterJoin(
            db.assetProfiles, db.assetProfiles.assetId.equalsExp(db.assets.id))
      ])
      .watch()
      .map((rows) {
        final assets = <String, Asset>{};
        final profiles = <String, List<StoredAssetProfile>>{};
        for (final row in rows) {
          final a = row.readTable(db.assets);
          assets[a.id] = a;
          final profile = row.readTableOrNull(db.assetProfiles);
          if (profile != null) (profiles[a.id] ??= []).add(profile);
        }
        return [for (final a in assets.values) _map(a, profiles[a.id] ?? [])];
      });
  @override
  Future<domain.Asset?> findById(String id) async {
    final row = await (db.select(db.assets)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final profiles = await (db.select(db.assetProfiles)
          ..where((p) => p.assetId.equals(id)))
        .get();
    return _map(row, profiles);
  }

  @override
  Future<String> add(
          {required String name,
          required String category,
          String brand = '',
          String model = '',
          Map<String, String> setup = const {}}) =>
      db.transaction(() async {
        setup = validateAssetSetup(category, setup);
        final id = const Uuid().v4();
        await db.into(db.assets).insert(AssetsCompanion.insert(
            id: id,
            name: name,
            category: category,
            assetSubtype: Value(AssetCategory.fromKey(category)?.subtypeKey),
            isCar:
                Value(category == 'vehicle' && setup['vehicle_type'] == 'car'),
            brand: Value(brand),
            model: Value(model),
            createdAt: DateTime.now()));
        await db.into(db.assetProfiles).insert(AssetProfilesCompanion.insert(
            assetId: id, category: category, detailsJson: jsonEncode(setup)));
        return id;
      });

  @override
  Future<void> archive(String id) async {
    await (db.update(db.assets)..where((a) => a.id.equals(id)))
        .write(const AssetsCompanion(archived: Value(true)));
  }

  @override
  Future<void> changeCategory(String id, String category,
          {Map<String, String> setup = const {}}) =>
      db.transaction(() async {
        final selected = AssetCategory.fromKey(category);
        if (selected == null) {
          throw ArgumentError('Choose a valid asset category.');
        }
        setup = validateAssetSetup(category, setup);
        final asset = await (db.select(db.assets)
              ..where((a) => a.id.equals(id)))
            .getSingleOrNull();
        if (asset == null || asset.archived) {
          throw StateError('This asset is missing or archived.');
        }
        final tasks = (await ForecastLocalStore(db).read())
            .tasks
            .where((t) => t.assetId == id);
        if (tasks.any((t) => t.subtype.name != selected.subtypeKey)) {
          throw StateError(
              'This asset already has plans for a different type. Keep its existing type to preserve compatible readings.');
        }
        await (db.update(db.assets)..where((a) => a.id.equals(id))).write(
            AssetsCompanion(
                category: Value(category),
                isCar: Value(category == 'vehicle' &&
                    (setup.containsKey('vehicle_type')
                        ? setup['vehicle_type'] == 'car'
                        : asset.isCar)),
                assetSubtype: Value(selected.subtypeKey)));
        await db.into(db.assetProfiles).insertOnConflictUpdate(
            AssetProfilesCompanion.insert(
                assetId: id,
                category: category,
                detailsJson: jsonEncode(setup)));
        await ForecastLocalStore(db).recalculate(id);
      });
}
