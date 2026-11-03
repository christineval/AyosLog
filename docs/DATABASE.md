# Database design

Schema **8** adds `maintenance_plans.reminder_days`, saved by the two-step asset
setup flow and used for in-app upcoming maintenance presentation. The first due
date is stored as `next_due`, alongside the existing `interval_months` recurrence.

Schema **7** adds `asset_profiles`, keyed by asset and category, for documented
asset setup values and `service_events.usage_unit` for canonical completion
readings. It also repairs missing/null default service metadata in early v5/v6
installations before Drift maps saved records. See `docs/FORM_REPAIR_QA.md`.

Schema **6** adds `assets.legacy_category` and replaces broad asset categories
with `vehicle`, `air_conditioner`, `refrigerator`, `laptop`, `water_filter`,
`washing_machine`, and `custom`. Explicit subtype evidence is used where present;
ambiguous existing entries become Custom/Other with their original label kept.
Asset IDs, service events and receipts are unchanged. Owners can choose the
specific category from Asset details. Existing forecast units are not retyped.

Schema **5** adds nullable `assets.asset_subtype`, service `voided`, `revision`,
`battery_replaced`, and six local tables: `forecast_policies`, `forecast_entries`,
`forecast_measures`, `forecast_signals`, `forecast_audits`, `forecast_snapshots`.
Policies reuse task-rule IDs. Entries and every repository mutation validate
asset/task ancestry. Numeric measures are REAL with canonical units; qualitative
signals use separate rows. Corrections are version-checked; deletions are
tombstones. Derived snapshots include exact inputs, policy/algorithm versions,
calculation UTC time and a stable input fingerprint. No cloud changes are applied.
See `docs/PREDICTIVE_IMPLEMENTATION.md` for migration/rollback policy.

Schema version 4 adds `service_events.performed_by` as non-null text with an empty default. Existing records remain unchanged and do not acquire an invented performer. New forms record the user's Self/repair-shop choice. A full app restart opens the database and runs this additive migration; hot reload alone does not reopen an already-open database connection.

## Local (implemented)
Drift SQLite database is initialized by `AppDatabase` in `lib/core/database/app_database.dart`.

| Table | Fields | Purpose |
|---|---|---|
| `assets` | id, name, category, brand, model, archived, created_at | Owned assets (local single-user scope) |
| `maintenance_plans` | id, asset_id FK, title, interval_months, next_due, active | Recurring date-based plans |
| `service_events` | id, asset_id FK, plan_id nullable FK, kind, description, cost, performed_at, receipt_path, maintenance_task nullable, odometer_km nullable | Maintenance event log |
| `usage_readings` | id, asset_id FK, odometer_km, recorded_at | Dated actual odometer readings used by local recommendation rules |
| `task_rules` | id, asset_id FK, task_name/key, component, metric, source, usage/days intervals, manufacturer usage/days limits, manufacturer_reference | Task-specific local tracking policy |
| `task_usage_readings` | id, asset_id FK, task_rule_id FK, value nullable, condition nullable, notes, recorded_at | Cumulative task counters or user condition observations |

Schema version 3 adds `assets.is_car` (default false), `service_events.task_rule_id`, `component` and `usage_value`, and the two task tables. v1 and v2 migrate forward without deleting old data or classifying vehicles automatically. Existing mileage rows are retained; no task unit is invented. New counters are isolated by asset and task rule, and car mileage additionally validates against the legacy asset-wide odometer. Task identity and unit are immutable once created. Manufacturer references/limits are user supplied, not a verified manufacturer database. These tables are local only; no cloud synchronization has been added.

Schema version 2 adds the two nullable service columns and creates `usage_readings`; existing records retain their data and receive no invented mileage or task labels. Service mileage inserts a usage reading in the same transaction as the service/linked plan update. Readings are validated against surrounding readings for that asset at SQLite's whole-second timestamp precision. Archiving retains readings and service history. This local schema addition is not cloud synchronization.

Local FKs are enabled with `PRAGMA foreign_keys = ON`. Add indexes and schema migration strategies before scale/release. `receipt_path` is a local device file path; it is not cloud-backed and may become unavailable if a picked file is cleaned up. Future implementation must copy captured bytes into app-private persistent storage.

## Cloud schema (provided, not wired)
Use `supabase/migrations/0001_initial.sql` for the complete cloud starter schema: `profiles`, `assets`, `asset_photos`, `maintenance_plans`, `maintenance_events`, `documents`, `usage_readings`, `reminder_preferences`, `change_log`.

**Local and cloud tables are deliberately not 1:1 yet.** Do not copy records naïvely or claim sync works; implement mappings, owner IDs, server-versioned outbox and conflict resolution.

## Data invariants
- Asset `name` must be nonempty, category must be valid.
- Monetary amount >= 0; use integer cents or SQL NUMERIC for production cloud financial totals (local scaffold uses REAL; migrate before audited financial reports).
- Service events are append-oriented; archive asset rather than erasing events.
- Completing a service with linked plan updates its next due date transactionally.
- All account data must be owner-scoped with server-side RLS before syncing.

## Database creation steps
1. Create a separate Supabase project and note your project URL and **publishable** key.
2. Open SQL Editor and inspect the migration; run it only in an empty dedicated project.
3. Confirm public tables and RLS policies exist via Table Editor.
4. Review `docs/SECURITY.md` and harden server triggers, policy join integrity and private storage before production.
5. Enable Auth email/password, create two test accounts and verify cross-user data isolation.
6. Keep SQLite local mode until remote repository and conflict-safe synchronization are implemented.
