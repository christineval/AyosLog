import 'dart:async';
import 'package:ayoslog/features/predictions/domain/forecast_models.dart';
import 'package:ayoslog/features/predictions/domain/forecast_repository.dart';

class FakeForecastRepository implements ForecastRepository {
  FakeForecastRepository(this.data, {this.error, this.loading = false});
  final ForecastData data;
  final Object? error;
  final bool loading;
  Completer<void>? gate;
  int writes = 0;
  ForecastTask? savedTask;
  Observation? savedObservation;
  ForecastCompletion? savedCompletion;
  @override
  Stream<ForecastData> watch() => loading
      ? const Stream.empty()
      : error != null
          ? Stream.error(error!)
          : Stream.value(data);
  Future<void> write() async {
    writes++;
    if (gate != null) await gate!.future;
  }

  @override
  Future<void> saveTask(ForecastTask task) async {
    savedTask = task;
    await write();
  }

  @override
  Future<void> saveObservation(Observation observation) async {
    savedObservation = observation;
    await write();
  }

  @override
  Future<void> deleteObservation(
          String assetId, String taskId, String id, int version) =>
      write();
  @override
  Future<void> complete(ForecastCompletion completion) async {
    savedCompletion = completion;
    await write();
  }
}

ForecastTask fixtureForecastTask(AssetSubtype subtype, {UsageMethod? method}) {
  final metric = switch (subtype) {
    AssetSubtype.vehicle => ForecastMetric.distance,
    AssetSubtype.airConditioner => ForecastMetric.hours,
    AssetSubtype.waterFilter => ForecastMetric.litres,
    AssetSubtype.washingMachine => ForecastMetric.cycles,
    AssetSubtype.refrigerator => ForecastMetric.temperature,
    AssetSubtype.laptop => ForecastMetric.battery,
    AssetSubtype.custom => ForecastMetric.custom
  };
  return ForecastTask(
      id: 't',
      assetId: 'a',
      name: 'Test maintenance',
      subtype: subtype,
      metric: metric,
      method:
          method ?? (metric.counter ? UsageMethod.counter : UsageMethod.trend),
      baselineAt: DateTime.utc(2025),
      interval: metric.counter ? 2000 : null,
      customUnit: 'units',
      dailyRate: method == UsageMethod.estimated ? 8 : null,
      setup: switch (subtype) {
        AssetSubtype.refrigerator => {'equipment_type': 'fridge'},
        AssetSubtype.laptop => {'device_type': 'laptop'},
        AssetSubtype.custom => {'metric_label': 'Usage'},
        _ => {}
      });
}
