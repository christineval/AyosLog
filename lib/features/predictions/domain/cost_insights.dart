import 'forecast_repository.dart';
import 'forecast_engine.dart';

class CostInsights {
  const CostInsights(this.total, this.monthlyAverage, this.medianCost,
      this.samples, this.unusual);
  final double total, monthlyAverage;
  final double? medianCost;
  final int samples;
  final bool unusual;
}

/// Same asset/task only. Costs are not failure indicators.
CostInsights calculateCostInsights(List<ForecastCompletion> services,
    String assetId, String taskId, DateTime now) {
  final comparable = services
      .where((s) =>
          !s.voided &&
          s.assetId == assetId &&
          s.taskId == taskId &&
          !s.at.isAfter(now))
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  final recent = comparable
      .where((s) => !s.at.isBefore(now.subtract(const Duration(days: 90))));
  final total = recent.fold(0.0, (v, s) => v + s.cost);
  final costs = comparable.map((s) => s.cost).toList();
  var unusual = false;
  if (costs.length >= 4) {
    final baseline = costs.sublist(0, costs.length - 1);
    final m = median(baseline);
    final deviation = median(baseline.map((v) => (v - m).abs()).toList());
    // Robust screening heuristic; 50% floor prevents zero-MAD false alarms.
    unusual =
        costs.last > m + (3 * deviation > m * .5 ? 3 * deviation : m * .5) &&
            costs.last > m;
  }
  return CostInsights(total, total / 3, costs.isEmpty ? null : median(costs),
      costs.length, unusual);
}
