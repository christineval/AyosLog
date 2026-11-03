# Predictive maintenance implementation

The supplied pack is at `Predictive_Maintenance_Documentation` (not
`Predictive_Maintenance_Docs`). Its stages extend the existing `predictions`
feature rather than creating another application.

## Acceptance and design decisions

- A: pure Dart, fixed-clock `rules_v1` engine; median chronological rates,
  explicit sources, states, evidence, and independent condition signals.
- B: additive v5 migration; retain all v1–v4 data and enum names. Reuse
  `task_rules` and linked `service_events`; store typed observations, revision
  audit, task policy and derived evidence snapshots locally.
- C–F: typed templates for vehicle/motorcycle, AC, filter, washer, refrigerator,
  laptop and custom; no bundled maintenance intervals.
- The user's subsequent instruction replaces broad asset categories with the
  seven documented categories throughout the app. Migration v6 preserves the
  original label in `legacy_category`, maps explicit subtype evidence, and
  assigns ambiguous older entries to Custom/Other for owner selection. Asset
  IDs, receipts, plans and history are retained. Category edits reject
  incompatible existing forecast plans instead of reinterpreting their units.
- D: Insights quick action, per-task details, check-in and correction history;
  existing bottom navigation, tokens, buttons and form layouts are reused.
- G: service completion uses the actual service date/reading; recompute in the
  same local transaction. Corrections retain audit evidence. Calendar shows
  applicable due dates. Notification delivery requires a separate platform
  permission/scheduling implementation and must not be implied by a card.
- H: excluded: authentication, outbox, Supabase, RLS and ML. This app remains
  single-owner, local-only; no invented account IDs or synchronization claim.

All new screens must show loading/error/empty states, explain local storage,
preserve failed drafts, prevent duplicate saves, and work in both themes.
Sensor input is unavailable; manual/imported observations are labelled.
Forecast status and freshness/reliability are separate; stale evidence cannot
hide a hard overdue limit or a condition signal.

## Implemented paths

- Domain: `forecast_models.dart`, `forecast_engine.dart`, `forecast_repository.dart`,
  `forecast_usecases.dart`, `category_templates.dart`, `cost_insights.dart` under
  `lib/features/predictions/domain`.
- Data: `forecast_local_store.dart`, `drift_forecast_repository.dart`; the existing
  maintenance repository calls the same store within its service transaction.
- MVVM: `forecast_viewmodels.dart`, `forecast_providers.dart`.
- Views: Insights, per-task prediction details, typed plan/check-in forms,
  condition checks, completion/correction form, reading/service/audit history,
  and the calendar's lazy Forecast dates section. Home and Asset details link
  to Insights; the four bottom destinations remain available.
- Assets: canonical `AssetCategory`, category creation/filter labels and a
  category-change use case, repository method, ViewModel action and screen.
- Drift: schema 5 introduces policies, entries, numeric measures, distinct
  qualitative signals, audit rows, derived snapshots and service revision,
  cancellation and battery replacement flags. Schema 6 changes categories
  while retaining original labels. Generated `app_database.g.dart` is included
  locally and must be regenerated after any schema edit.
- `supabase/migrations/0002_asset_categories.sql` is reference-only and **unapplied**.
  No authenticated service, outbox, RLS deployment or cloud sync was enabled.

## Algorithm assumptions

`rules_v1` uses chronological adjacent-pair rates and their median (zero rates
remain evidence; negative counters require an explicit meter-reset entry).
Counter replacements retain already-consumed use and start a new rate segment.
Dates are anchored to the last actual reading and rounded up to whole days.
Owner-entered estimated usage accumulates in dated segments; a check-in changes
the rate only from its observation time. No date is fabricated for a zero rate.
The earlier usage/calendar limit wins, including when readings are stale.
Warning/freshness settings are editable; defaults are UI planning thresholds,
not manufacturer service intervals or probabilities.

Condition review signals remain independent of due status. Refrigerator trends
need three distinct dates and repeated outliers against an owner-supplied range;
battery trends do not extrapolate a failure date. Battery replacement resets the
trend; ordinary cleaning/checking does not. Supported 30/60/90-day battery slopes
require three readings spanning at least 80% of the labelled window. Cost
screening compares only the same asset/task, with at least three earlier costs,
using median/MAD and a 50% floor when history has no variation.

Service completion uses the actual completion date and counter, atomically
updates the cache, and supplies a measured baseline point for subsequent rates.
Correction/cancellation retains the earlier event in the audit. Linked monthly
recurrence is recalculated from the latest non-cancelled event; if none remain,
it uses the configured initial baseline. Cancelled rows are retained and excluded
from active service lists and forecasts.

Local timestamps are stored as UTC; observation validation matches SQLite's
whole-second resolution. Numeric and qualitative values are stored separately.
Sensor source selection is unavailable. All IDs generated by the UI use UUIDs;
`local_owner` audit actors describe this device's single-owner mode, not an
authenticated identity. A stable input fingerprint identifies evidence; it is
not a cryptographic signature.

Back up the SQLite file before upgrading. Do not downgrade a migrated database;
rollback means restoring that backup with its matching application version.
Recalculation does not delete original readings. Snapshots are derived caches;
screens recalculate from source data and refresh freshness while open.

## Remaining platform/infrastructure work

Automatic OS notification delivery is not implemented. Calendar forecast cards
explicitly describe planning dates rather than scheduled notifications. Stage H
(authenticated sync/RLS/outbox) and trained ML remain excluded. iOS builds require
macOS/Xcode; store signing, cloud security tests and full physical-device QA are
not implied by automated tests or an Android debug build.

## Verification

- `dart run build_runner build`: passed; the generated Drift file contains all
  new tables and columns. This resolves the reported undefined getter/migration
  parameter errors.
- `dart format lib test`: passed.
- `flutter analyze`: passed, no issues.
- `flutter test`: **151 passed**. Includes the prior application tests, category
  upgrades from v4/v5, prior v1–v3 migration regressions, source durability after
  reopening, canonical units, all category templates, all forecast states,
  duplicate submit/retry, chronological corrections, same-second conflicts,
  meter/battery resets, atomic rollback and service recalculation. Both themes,
  small screens, 200% text and keyboard states are covered by widget tests.
- `flutter build apk --debug`: passed, producing
  `build/app/outputs/flutter-apk/app-debug.apk`.
- After the final vehicle-unit label clarification, analysis passed again and
  the focused form/widget suite passed **40 tests**. The Android APK was rebuilt.
- This revision has **not** been installed or manually exercised on the phone.
  No iOS/release build, notification-delivery test, RLS test or cloud deployment
  was performed. Stage G is complete for local recalculation/corrections and
  calendar display; automatic notification delivery remains pending.

The repository's current files are all untracked in Git, so no trustworthy
tracked-baseline diff is available. No commit, reset or cloud deployment was
performed. The changed areas for review are the paths listed above plus
`lib/core/{database,router}`, existing assets/maintenance/home/calendar integration
files, the new `test/{forecast_*,asset_categories_test.dart}` files and helpers,
and README/DESIGN/architecture/database/changelog documentation.

## File inventory

New files:

```text
lib/features/assets/domain/entities/asset_category.dart
lib/features/assets/domain/usecases/change_asset_category.dart
lib/features/assets/presentation/views/asset_category_page.dart
lib/features/predictions/domain/forecast_models.dart
lib/features/predictions/domain/forecast_engine.dart
lib/features/predictions/domain/forecast_repository.dart
lib/features/predictions/domain/forecast_usecases.dart
lib/features/predictions/domain/category_templates.dart
lib/features/predictions/domain/cost_insights.dart
lib/features/predictions/data/forecast_local_store.dart
lib/features/predictions/data/drift_forecast_repository.dart
lib/features/predictions/presentation/forecast_providers.dart
lib/features/predictions/presentation/viewmodels/forecast_viewmodels.dart
lib/features/predictions/presentation/views/forecast_widgets.dart
lib/features/predictions/presentation/views/insights_page.dart
lib/features/predictions/presentation/views/forecast_forms.dart
lib/features/predictions/presentation/views/forecast_history_page.dart
lib/features/predictions/presentation/views/forecast_calendar_section.dart
test/asset_categories_test.dart
test/forecast_engine_test.dart
test/forecast_repository_test.dart
test/forecast_forms_test.dart
test/forecast_widget_test.dart
test/helpers/fake_forecast_repository.dart
supabase/migrations/0002_asset_categories.sql
docs/PREDICTIVE_IMPLEMENTATION.md
```

Existing integration files adjusted:

```text
lib/core/database/app_database.dart
lib/core/database/app_database.g.dart (generated)
lib/core/router/app_router.dart
lib/features/assets/domain/entities/asset.dart
lib/features/assets/domain/repositories/asset_repository.dart
lib/features/assets/domain/usecases/create_asset.dart
lib/features/assets/data/repositories/drift_asset_repository.dart
lib/features/assets/presentation/viewmodels/asset_form_viewmodel.dart
lib/features/assets/presentation/views/add_asset_page.dart
lib/features/assets/presentation/views/assets_page.dart
lib/features/assets/presentation/views/asset_detail_page.dart
lib/features/maintenance/data/maintenance_repository.dart
lib/features/maintenance/data/drift_service_history_repository.dart
lib/features/maintenance/presentation/views/add_service_page.dart
lib/features/predictions/data/drift_prediction_repository.dart
lib/features/home/presentation/views/home_page.dart
lib/features/calendar/presentation/views/calendar_page.dart
test/helpers/fake_asset_repository.dart
test/prediction_widget_test.dart
README.md
DESIGN.md
CHANGELOG.md
docs/ARCHITECTURE.md
docs/DATABASE.md
```

The requested formatting pass also reformatted `test/receipt_scan_test.dart`.
