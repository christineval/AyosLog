import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayoslog/core/database/app_database.dart';
import 'package:ayoslog/features/assets/domain/entities/asset_category.dart';
import 'package:ayoslog/features/assets/domain/usecases/create_asset.dart';
import 'package:ayoslog/features/assets/data/repositories/drift_asset_repository.dart';
import 'package:ayoslog/features/predictions/domain/category_templates.dart';

class _PreviousDatabase extends AppDatabase {
  _PreviousDatabase(super.executor, this.version) : super.forExecutor();
  final int version;
  @override
  int get schemaVersion => version;
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (m) async {
        await m.createAll();
        if (version < 6) {
          await customStatement(
              'ALTER TABLE assets DROP COLUMN legacy_category');
        }
        await customStatement('DROP TABLE asset_profiles');
        await customStatement(
            'ALTER TABLE service_events DROP COLUMN usage_unit');
        if (version == 4) {
          for (final table in [
            'forecast_snapshots',
            'forecast_audits',
            'forecast_signals',
            'forecast_measures',
            'forecast_entries',
            'forecast_policies'
          ]) {
            await customStatement('DROP TABLE $table');
          }
          await customStatement('ALTER TABLE assets DROP COLUMN asset_subtype');
          for (final column in ['battery_replaced', 'voided', 'revision']) {
            await customStatement(
                'ALTER TABLE service_events DROP COLUMN $column');
          }
        }
      });
}

void main() {
  test('exactly the seven category keys map to their matching templates', () {
    expect(AssetCategory.values.map((c) => c.key).toSet(), {
      'vehicle',
      'air_conditioner',
      'refrigerator',
      'laptop',
      'water_filter',
      'washing_machine',
      'custom'
    });
    for (final c in AssetCategory.values) {
      expect(subtypesForCategory(c.key).single.name, c.subtypeKey);
    }
  });
  for (final prior in [4, 5]) {
    test(
        'v$prior to current schema preserves records and original broad categories',
        () async {
      final dir = await Directory.systemTemp
          .createTemp('ayoslog_v${prior}_categories_');
      final file = File('${dir.path}/legacy.sqlite');
      final old = _PreviousDatabase(NativeDatabase(file), prior);
      for (final c in [
        'vehicle',
        'appliance',
        'electronics',
        'home',
        'other'
      ]) {
        await old.customStatement(
            'INSERT INTO assets(id,name,category,created_at) VALUES (?,?,?,?)',
            [c, c, c, 1700000000]);
      }
      if (prior == 5) {
        await old.customStatement(
            "UPDATE assets SET asset_subtype='airConditioner' WHERE id='appliance'");
      }
      await old.customStatement(
          "INSERT INTO service_events(id,asset_id,kind,description,cost,performed_at,performed_by,receipt_path) VALUES ('s','appliance','routine','Preserved work',450,1700000000,'MotoCare','local.jpg')");
      await old.close();
      final upgraded = AppDatabase.forExecutor(NativeDatabase(file));
      try {
        final assets = await upgraded.select(upgraded.assets).get();
        expect(assets.length, 5);
        expect(assets.firstWhere((a) => a.id == 'vehicle').category, 'vehicle');
        final appliance = assets.firstWhere((a) => a.id == 'appliance');
        expect(appliance.category, prior == 5 ? 'air_conditioner' : 'custom');
        expect(appliance.legacyCategory, 'appliance');
        expect(
            assets.firstWhere((a) => a.id == 'electronics').category, 'custom');
        final service =
            (await upgraded.select(upgraded.serviceEvents).get()).single;
        expect(service.cost, 450);
        expect(service.performedBy, 'MotoCare');
        expect(service.receiptPath, 'local.jpg');
        expect(service.voided, false);
        expect(await upgraded.select(upgraded.forecastEntries).get(), isEmpty);
        await DriftAssetRepository(upgraded).changeCategory(
            'electronics', 'laptop',
            setup: const {'device_type': 'laptop'});
        expect(
            (await upgraded.select(upgraded.assets).get())
                .firstWhere((a) => a.id == 'electronics')
                .legacyCategory,
            'electronics');
      } finally {
        await upgraded.close();
        await dir.delete(recursive: true);
      }
    });
  }
  test(
      'create and reclassify validate categories without changing asset id or service history',
      () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    try {
      final repo = DriftAssetRepository(db);
      for (final c in AssetCategory.values) {
        final id = await CreateAsset(repo)(
            name: c.label,
            category: c.key,
            setup: switch (c) {
              AssetCategory.refrigerator => {'equipment_type': 'fridge'},
              AssetCategory.laptop => {'device_type': 'laptop'},
              _ => {}
            });
        expect((await repo.findById(id))!.category, c.key);
      }
      expect(
          () => CreateAsset(repo)(name: 'Old category', category: 'appliance'),
          throwsArgumentError);
      final id = (await repo.watchAssets().first).first.id;
      await repo.changeCategory(id, 'water_filter');
      expect((await repo.findById(id))!.category, 'water_filter');
    } finally {
      await db.close();
    }
  });
}
