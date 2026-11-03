# Architecture — Clean Architecture + MVVM

```
View (Flutter) → ViewModel (Riverpod StateNotifier)
                      ↓
                Use case (domain)
                      ↓
          Repository interface (domain)
                      ↑ implemented by
                Drift repository (data)
                      ↓
             Drift / SQLite (local)
```

The arrow from data to domain denotes **source dependency**. The runtime call sequence is View → VM → Use case → repository implementation → database. `lib/core/providers.dart` is the composition root.

## Current feature modules
- `predictions` now also contains the pure Dart `rules_v1` engine, typed category
  templates, forecast use cases/repository contracts and cost calculations.
  Drift adapters own source/audit/cache transactions. StateNotifier ViewModels
  subscribe to domain data and build Insights; dynamic views render definitions
  using shared widgets, without issuing SQL or calculating forecasts.
- `assets`: entity, contract, CreateAsset use case, Drift repository, asset form VM, list, create, detail/archive.
- `maintenance`: recurrence logic, transactional event and plan writes, screens for monthly plan and maintenance record, history.
- Service history/details use a pure-Dart record/repository/use-case boundary, a Drift read repository and Riverpod StateNotifier ViewModels. Detail views receive saved records rather than constructing queries. Receipt viewing handles unavailable files without deleting history.
- `home`: reactive summary and upcoming due list.
- `calendar`: chronologically sorted due list (month-grid Figma treatment not yet implemented).
- `settings`: persisted theme selection.
- `predictions`: pure-Dart task-specific time/usage/condition rules, source/limit validation and repository contract, Drift implementation, Riverpod ViewModels, task configuration and counter/observation forms, and reactive cards for every asset category. Service/task usage/linked recurrence changes are atomic. Manufacturer inputs are explicitly user-entered references.
- `shared/widgets`: design system building blocks.
- `core/theme`: single source of theme truth.
- `core/database`: Drift schema & generated code.

## Scope gap (must not confuse with production-ready)
Not implemented: authentication, cloud sync/outbox, Supabase Storage, actual notification scheduling, warranty CRUD, advanced filtering, multiple currency/timezones, dedicated OCR field parser, usage-based schedules, predictive ML, household roles, data export, full widget/integration coverage. The `supabase_flutter` and notification dependencies are reserved for subsequent features. ML Kit is called from a screen in this scaffold and should be extracted to a document data source before expanding OCR.

## Recommended next features
1. Implement `AuthRepository` plus Supabase Auth login/signup and profile provisioning.
2. Add outbox/change-log versioning and sync coordinator; block cloud writes without tested RLS.
3. Add receipt/warranty files as private local objects with explicit retention, and Supabase private Storage upload.
4. Convert OCR into `ScanReceipt` use case plus an explicit reviewed-field draft.
5. Local notifications with permission, scheduling and boot reconciliation.
6. Extend maintenance plans to km/hours/cycles and explainable forecasts.

## Test boundaries
Unit-test recurrence and validation with pure Dart. Repository-test Drift with in-memory DB. Widget-test error/empty states for every route. E2E-test offline persistence and migrations. Security-test RLS with two test users.
