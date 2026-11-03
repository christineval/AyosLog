import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/maintenance_insight.dart';
import '../forecast_providers.dart';

final assetMaintenanceInsightsProvider = Provider.autoDispose
    .family<AsyncValue<List<MaintenanceInsight>>, String>((ref, id) {
  final current = ref.watch(insightsProvider),
      legacy = ref.watch(predictionProvider(id));
  if (current.isLoading) return const AsyncLoading();
  if (current.hasError) return AsyncError(current.error!, current.stackTrace!);
  final data = current.requireValue;
  final asset =
      data.source.assets.where((a) => a.id == id && !a.archived).firstOrNull;
  if (asset == null) return const AsyncData([]);
  const build = BuildMaintenanceInsight();
  final rows = [
    for (final i
        in data.insights.where((i) => i.assetId == id && i.prediction != null))
      build.forecast(i)
  ];
  if (legacy.hasValue) {
    rows.addAll(legacy.requireValue.recommendations
        .where(
            (r) => r.rule != null && !rows.any((i) => i.taskId == r.rule!.id))
        .map((r) =>
            build.legacy(id, asset.name, asset.category, r, DateTime.now())));
  } else if (rows.isEmpty && legacy.isLoading) {
    return const AsyncLoading();
  } else if (rows.isEmpty && legacy.hasError) {
    return AsyncError(legacy.error!, legacy.stackTrace!);
  }
  if (rows.isEmpty) rows.add(build.empty(id, asset.name, asset.category));
  int rank(MaintenanceInsight i) => switch (i.tone) {
        InsightTone.overdue => 0,
        InsightTone.review => 1,
        InsightTone.normal => 2,
        InsightTone.neutral => 3
      };
  rows.sort((a, b) => rank(a).compareTo(rank(b)));
  return AsyncData(rows);
});
