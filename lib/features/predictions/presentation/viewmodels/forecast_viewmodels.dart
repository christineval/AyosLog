import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/forecast_models.dart';
import '../../domain/forecast_repository.dart';
import '../../domain/forecast_usecases.dart';
import '../../domain/category_templates.dart';
import '../../domain/cost_insights.dart';

class ForecastScreenData {
  const ForecastScreenData(this.source, this.insights, [this.costs = const {}]);
  final ForecastData source;
  final List<AssetInsight> insights;
  final Map<String, CostInsights> costs;
}

class InsightsViewModel extends StateNotifier<AsyncValue<ForecastScreenData>> {
  InsightsViewModel(ForecastRepository repository, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const AsyncLoading()) {
    subscription = repository.watch().listen((data) {
      last = data;
      refresh();
    }, onError: (Object e, StackTrace s) {
      if (mounted) state = AsyncError(e, s);
    });
    timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }
  final DateTime Function() clock;
  late final StreamSubscription<ForecastData> subscription;
  late final Timer timer;
  ForecastData? last;
  void refresh() {
    if (last == null || !mounted) return;
    try {
      final now = clock().toUtc();
      state = AsyncData(
          ForecastScreenData(last!, const CalculateInsights()(last!, now), {
        for (final t in last!.tasks)
          t.id: calculateCostInsights(last!.completions, t.assetId, t.id, now)
      }));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  @override
  void dispose() {
    timer.cancel();
    subscription.cancel();
    super.dispose();
  }
}

class ForecastFormViewModel extends StateNotifier<AsyncValue<void>> {
  ForecastFormViewModel(this.repository) : super(const AsyncData(null));
  final ForecastRepository repository;
  Future<bool> submit(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (mounted) {
        state = AsyncError(
            e is ForecastValidation
                ? e
                : const ForecastValidation(
                    'Could not save locally. Your draft is kept; please retry.'),
            s);
      }
      return false;
    }
  }

  Future<bool> savePlan(
          {required String id,
          required String assetId,
          required String name,
          required AssetSubtype subtype,
          required UsageMethod method,
          required DateTime baselineAt,
          required PlanSource source,
          required String reference,
          required Map<String, String> values,
          int version = 1}) =>
      submit(() => SaveForecastTask(repository)(buildForecastTask(
          id: id,
          assetId: assetId,
          name: name,
          subtype: subtype,
          method: method,
          baselineAt: baselineAt,
          source: source,
          reference: reference,
          values: values,
          version: version,
          now: DateTime.now().toUtc())));
  Future<bool> saveReading(
          {required ForecastTask task,
          required String id,
          required Map<String, String> values,
          required DateTime at,
          required EvidenceSource source,
          required String notes,
          required bool reset,
          required bool confirmed,
          int version = 1,
          bool conditionsOnly = false}) =>
      submit(() => RecordObservation(repository)(buildObservation(
          task: task,
          id: id,
          values: values,
          at: at,
          now: DateTime.now().toUtc(),
          source: source,
          notes: notes,
          reset: reset,
          confirmed: confirmed,
          version: version,
          conditionsOnly: conditionsOnly)));
  Future<bool> deleteReading(Observation o) => submit(
      () => repository.deleteObservation(o.assetId, o.taskId, o.id, o.version));
  Future<bool> complete(ForecastCompletion c, {String distanceUnit = 'km'}) =>
      submit(() =>
          CompletePredictedTask(repository)(c, distanceUnit: distanceUnit));
}
