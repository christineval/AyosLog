import 'forecast_engine.dart';
import 'forecast_models.dart';
import 'forecast_repository.dart';
import 'category_templates.dart';

class CalculateInsights {
  const CalculateInsights();
  List<AssetInsight> call(ForecastData data, DateTime now) {
    final result = <AssetInsight>[];
    for (final asset in data.assets.where((a) => !a.archived)) {
      final tasks = data.tasks.where((t) => t.assetId == asset.id);
      if (tasks.isEmpty) {
        result.add(AssetInsight(asset.id, asset.name, asset.category, null));
      }
      for (var task in tasks) {
        final originalTrendAt = task.baselineAt;
        Observation? completionReading;
        final completions = data.completions
            .where((c) =>
                c.taskId == task.id &&
                c.assetId == task.assetId &&
                !c.voided &&
                !c.at.isAfter(now) &&
                !c.at.isBefore(task.baselineAt))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
        if (completions.isNotEmpty) {
          final c = completions.last;
          // A missing counter must not suppress an independent calendar limit.
          if (task.metric.counter &&
              task.method == UsageMethod.counter &&
              c.value == null) {
            task = ForecastTask.fromJson({
              ...task.withBaseline(c.at, task.baseline).toJson(),
              'baselineKnown': false
            });
          } else {
            task = task.withBaseline(c.at, c.value ?? 0);
          }
          if (task.metric == ForecastMetric.battery) {
            final replacements =
                completions.where((c) => c.batteryReplaced).toList();
            task = ForecastTask.fromJson({
              ...task.toJson(),
              'trendSince': (replacements.isEmpty
                      ? originalTrendAt
                      : replacements.last.at)
                  .toUtc()
                  .toIso8601String()
            });
          }
          if (task.metric.counter &&
              task.method == UsageMethod.counter &&
              c.value != null) {
            completionReading = Observation(
                id: 'service:${c.id}',
                assetId: task.assetId,
                taskId: task.id,
                at: c.at,
                values: {'reading': c.value!},
                notes: 'Actual counter recorded at service completion.');
          }
        }
        result.add(AssetInsight(
            asset.id,
            asset.name,
            asset.category,
            const PredictionEngine().calculate(
                task,
                [
                  if (completionReading != null) completionReading,
                  ...data.observations
                ],
                now)));
      }
    }
    int rank(ForecastState s) => switch (s) {
          ForecastState.overdue => 0,
          ForecastState.dueSoon => 1,
          ForecastState.conditionAlert => 2,
          ForecastState.invalid => 3,
          ForecastState.stale => 4,
          ForecastState.notConfigured => 5,
          ForecastState.insufficientData => 6,
          _ => 7,
        };
    result.sort((a, b) {
      final n = rank(a.state).compareTo(rank(b.state));
      return n == 0 ? a.assetName.compareTo(b.assetName) : n;
    });
    return result;
  }
}

class SaveForecastTask {
  const SaveForecastTask(this.repository);
  final ForecastRepository repository;
  Future<void> call(ForecastTask task) {
    validateForecastTask(task, DateTime.now().toUtc());
    final errors = validateCategoryFields(
        categoryTemplates[task.subtype]!.setup, task.setup);
    if (errors.isNotEmpty) throw ForecastValidation(errors.values.first);
    return repository.saveTask(task);
  }
}

class RecordObservation {
  const RecordObservation(this.repository);
  final ForecastRepository repository;
  Future<void> call(Observation observation) =>
      repository.saveObservation(observation);
}

class CompletePredictedTask {
  const CompletePredictedTask(this.repository);
  final ForecastRepository repository;
  Future<void> call(ForecastCompletion c, {String distanceUnit = 'km'}) {
    if (distanceUnit == 'mi') {
      c = c.withValue(c.value == null ? null : canonicalValue(c.value!, 'mi'));
    }
    if (!c.cost.isFinite ||
        c.cost < 0 ||
        c.description.trim().isEmpty ||
        c.description.length > 1000 ||
        c.at.isAfter(DateTime.now()) ||
        c.value != null &&
            (!c.value!.isFinite || c.value! < 0 || c.value! > 1e12)) {
      throw const ForecastValidation(
          'Check the service date, work, cost and completion reading.');
    }
    if (!['routine', 'inspection', 'repair', 'other'].contains(c.kind)) {
      throw const ForecastValidation('Choose a valid service type.');
    }
    return repository.complete(c);
  }
}
