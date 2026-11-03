# Implementation architecture, APIs and algorithm contract

## Clean Architecture + MVVM feature tree

```text
lib/features/prediction/
  domain/
    entities/{asset_observation,condition_observation,maintenance_prediction,prediction_evidence}.dart
    repositories/{observation_repository,prediction_repository}.dart
    services/prediction_engine.dart
    usecases/{record_observation,calculate_prediction,list_asset_insights,complete_predicted_task}.dart
  data/
    datasources/{observation_local_datasource,prediction_local_datasource}.dart
    engines/{usage_forecast_engine,condition_rules_engine}.dart
    repositories/{observation_repository_impl,prediction_repository_impl}.dart
    models/{observation_dto,prediction_dto}.dart
  presentation/
    viewmodels/{insights_viewmodel,asset_prediction_viewmodel,check_in_viewmodel}.dart
    views/{insights_page,asset_insights_page,asset_check_in_page,usage_history_page}.dart
    widgets/{prediction_card,confidence_explanation,metric_field,status_chip,reading_chart}.dart
lib/core/
  theme/{app_colors,app_text_styles,app_theme,component_themes}.dart
  widgets/{app_button,app_card,app_text_field,app_dropdown,app_date_picker,app_empty_state}.dart
```

**Dependency direction:** presentation → domain contracts/use cases; data → domain contracts. Domain knows neither Flutter nor Drift nor Supabase. Register implementations with Riverpod providers; widget calls VM action, VM calls use case, use case invokes repository + prediction engine, repository persists locally. Keep calculation in pure Dart to unit test. Existing architecture naming may differ: adapt instead of duplicating core modules.

## Domain entities (conceptual)

```text
AssetUsageObservation(id, assetId, metricKey, decimalValueCanonical, unitCanonical,
  observedAtUtc, source, notes, createdBy, deletedAtUtc?, version)
AssetConditionObservation(id, assetId, conditionKey, enumValue, observedAtUtc,
  source, severity?, notes, createdBy, version)
MaintenanceTask(id, assetId, taskType, intervalUsage?, usageUnit?, intervalDays?,
  baselineUsage?, baselineServiceAtUtc?, sourceType, sourceReference?, warningDays?, version)
MaintenancePrediction(id, assetId, taskId, state, dueAtUtc?, usageTarget?,
  remainingUsage?, reliability, rationale[], inputCount, latestObservationAtUtc?,
  algorithmVersion, calculatedAtUtc, inputHash)
```

Store predictions as a cache. Source observations and service records are the durable truths.

## Function contracts and pseudocode

```dart
abstract interface class PredictionEngine {
  MaintenancePrediction calculate({
    required MaintenanceTask task,
    required List<AssetUsageObservation> usageReadings,
    required List<AssetConditionObservation> conditionReadings,
    required DateTime nowUtc,
  });
}
```

```text
function calculate(task, readings, conditions, now):
  verify task interval > 0 and unit consistency
  sanitize readings: sort, deduplicate same timestamp, apply known counter resets
  if last reading < task baseline for non-resettable metric: INVALID
  remaining = target - lastReading.value (if applicable)
  rates = pairwise positive delta(value) / delta(days), exclude invalid intervals
  rate = median(rates) when enough observations; else 2-point rate if valid
  usageDue = lastReading.timestamp + ceil(max(0,remaining) / rate) days when rate > 0
  calendarDue = task.baselineServiceAt + task.intervalDays if provided
  due = earlier non-null of usageDue, calendarDue
  state = overdue if any HARD threshold crossed; else due_soon if within threshold
          else estimated if usageDue exists; else scheduled if calendarDue exists
          else insufficient_data if task exists; otherwise not_configured
  condition alerts are independent, never suppress hard due date
  reliability = limited if <3 valid observation pairs or stale; moderate only if
                sample count and variability rules pass; never probabilistic confidence
  persist exact evidence snapshot, task version, algorithm_version='rules_v1'
```

**Test invariants:** increasing counters; fixed clock test; leap-day/calendar month semantics; UTC storage, local display; no division by zero; decimal precision and conversion; date outliers; multiple simultaneous task types; older observations inserted; complete service resets only that task. Keep thresholds in user/manufacturer plans, not engine constants.

## Data flow / transactions

1. UI picks asset and form template from subtype.
2. VM validates form, converts units to canonical values.
3. `RecordObservation` persists observation + sync outbox event in local transaction.
4. Engine evaluates affected tasks; prediction cache updates in same transaction or scheduled deterministic job.
5. Reactive Drift watches update cards and charts.
6. If online/authenticated, a separate sync worker mirrors owner-scoped source records to Supabase.
7. Recompute after remote conflict resolutions. Predictions may be local-only or versioned server-derived, but never allow a stale result to overwrite newer source measurements.

## Error model

`invalid_metric`, `untrusted_source`, `unit_mismatch`, `counter_reset_required`, `missing_baseline`, `insufficient_readings`, `stale_reading`, `storage_failure`, `ownership_denied`, `sync_conflict`. UI maps each to inline error with next action and preserves draft form values.

## Suggested API endpoints only if needed

Offline MVP requires **no prediction API**. For cloud sync: `GET/POST /assets/:id/observations`, `GET/POST /assets/:id/conditions`, `GET/PUT /assets/:id/tasks`; use Supabase SDK with RLS or a secured backend, not both without justification. Authentication and user isolation must be implemented before enabling shared cloud endpoints.
