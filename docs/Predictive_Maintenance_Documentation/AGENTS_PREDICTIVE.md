# AGENTS.md — Predictive Maintenance Implementation Instructions

**Mission:** Integrate the specification into the existing Maintly/AyosLog Flutter app; do not create a second app or replace unrelated source files. The master references are `PREDICTIVE_MAINTENANCE_SPEC.md`, `CATEGORY_FORMS.md`, `ARCHITECTURE_AND_CALCULATIONS.md`, `DATABASE_MIGRATION_PLAN.md`. Follow the repository's existing `AGENTS.md`, `DESIGN.md`, migrations, and auth/security contracts where they are stricter.

## Mandatory discovery

1. Inspect `pubspec.yaml`, Flutter version, existing theme and widgets, current feature folder naming and routes, Drift database tables/migrations, existing asset categories and service/task schema, auth and Supabase integration status. No assumption that cloud sync is implemented.
2. Compare current code to this spec; record reusable modules and necessary migration steps. **Never** remove existing data or rename a persisted enum without migration.
3. Develop independently testable pure-Dart calculation engine, domain interfaces and fixtures before UI.

## Build sequence and checkpoints

- [ ] Stage A: typed domain models (`Observation`, `Task`, `Prediction`, evidence and reliability enums) + 2-point/median usage-rate engine + comprehensive unit tests.
- [ ] Stage B: Drift tables/migration and repository implementations with ownership and local transactions; data correction and chronological ordering tests.
- [ ] Stage C: subtype mapping for current categories, dynamic forms and validation (`CATEGORY_FORMS.md`). Implement vehicle end to end first.
- [ ] Stage D: Insights dashboard + Asset Prediction + Record Reading + History, using shared tokenized components and light/dark states.
- [ ] Stage E: AC and water filter, then washing machine usage forecasts; condition reports separate from numeric estimates.
- [ ] Stage F: Refrigerator trend and laptop condition tracking without fictional failure probability.
- [ ] Stage G: service-completion recalculation, calendar/notifications integration, history corrections, error/offline/stale state QA.
- [ ] Stage H: optional authenticated Supabase sync only after RLS, isolation and conflict handling; future ML deliberately out of MVP.

## Guardrails

- Clean Architecture + MVVM with Riverpod. Views hold no business calculations or SQL. Domain imports no Flutter, Drift, network packages.
- Use current Figma theme and shared widgets. Keep dark/light status semantic contrast and accessibility; never hardcode a new brand purple/orange.
- Do not claim predictive ML, arbitrary manufacturer schedules, automatic sensors, calibrated confidence, or confirmed diagnoses.
- Distinguish `estimated`, `scheduled`, `overdue`, `stale`, `insufficient_data`, and `condition_alert` explicitly.
- Keep offline operations fully usable. A cloud failure must not lose a check-in. Scope records by authenticated owner before multiuser sync.
- Capture algorithm version, inputs, timestamp and assumptions. Recompute after any edit/delete/service completion. Idempotent persistence and no duplicate notifications.
- Never say “done” without passing `dart format`, `flutter analyze`, `flutter test` and platform build on the developer machine; disclose unverified steps.

## Acceptance suite

Use fixtures: vehicle 8000→9450km, 2000km interval, 210km/week; AC 8h/day x35days; water filter 2000L with 12L/day; washer 35/50 cycles at 7 cycles/week; refrigerator increasing readings; laptop downward battery-health readings. Test unit conversions, stale data, no readings, equal timestamps, odometer correction/reset, zero rate, counter regression, calendar earlier limit, completed service, RLS, light/dark rendering, invalid inputs and empty states.

## Agent handoff output

Report: changed paths, migration IDs, algorithm assumptions, which categories are finished, exact tests run and their results, unapplied cloud changes, unresolved risks and next implementation stage. Don't claim full production readiness until authentication, RLS, sync and platform builds are verified.
