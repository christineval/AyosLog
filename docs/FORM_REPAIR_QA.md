# Category forms and asset setup flow — 2026-11-02

`Predictive_Maintenance_Documentation/CATEGORY_FORMS.md` is retained unchanged as
the form contract. Asset setup, plans, check-ins/conditions and completed-service
fields belong to their respective screens. The earlier asset screen omitted the
setup fields even though they existed in the plan renderer; this is corrected.

## Repairs

- Device logs identified a Future-returning `setState` callback when returning
  from category editing. Asset refresh/retry now assigns its pending Future in
  a synchronous block.
- A temporary copy of the actual phone database reproduced the service mapper's
  null assertion on the battery-replacement flag. This also interrupted category
  changes because they read service history while recalculating. Migration 7
  checks physical service columns, adds missing metadata and normalizes null
  default flags without deleting records. The repaired loader successfully read
  the saved service from that copy; temporary database/test files were deleted.
- Category creation/editing renders the documented setup fields immediately,
  validates them and stores profiles per asset/category. Switching category
  retains the previous category's setup data.
- Plan entry from the asset/calendar uses the typed category forms. The normal
  service form includes the category's completion reading and can link a
  configured plan. Linked completion preserves receipt/performer information
  and updates its baseline through the existing transaction/recalculation path.
- Upcoming cards use the asset name as the heading and service type/date below.
  Configured forecast dates are also included on Home.

## New onboarding flow

1. **Step 1 of 2 — Add an asset:** category-specific setup, then Continue.
   The validated asset is saved locally once before the next screen.
2. **Step 2 of 2 — Set maintenance plan:** task title, repeat schedule, required
   first due date and reminder lead time. Save asset & schedule writes the plan
   for that asset. Skip creates no plan and opens the saved asset details.

The service form's optional plan selector accepts both calendar schedules and
usage/condition plans. Calendar completion forwards the plan ID to the existing
atomic service/recurrence transaction; usage completion updates its typed task.

The step-2 screen links to category-specific usage/condition plan settings;
saving or skipping that variant also finishes setup. Asset data survives closing
the app between steps. Plan writes use a stable UUID and duplicate-submit guard.

Schema **7** adds `asset_profiles` (asset/category key, validated setup JSON) and
`service_events.usage_unit`, alongside the legacy service-column compatibility
repair. Schema **8** adds `maintenance_plans.reminder_days` (default 7, matching
the previous in-app due-soon window). First due date is stored in `next_due`;
`interval_months` controls existing recurrence. Reminder lead time controls the
in-app upcoming/soon presentation. This does not enable OS notification delivery.

## Verification scope

- The regression suite passed **161 tests** after the category/service repair,
  before the additional two-step-flow change.
- Actual-device database-copy service loading passed after the compatibility
  repair; no user record content was printed or sent anywhere.
- Added tests cover Continue/Skip, required date validation, persisted repeat and
  reminder values, one-asset/idempotent saving and duplicate-submit protection.
  The targeted run for these new tests was declined at the permission prompt,
  so those test results are not yet verified.
- Final `flutter analyze`: passed with no issues after the two-step-flow change.
- Android integration testing uses an isolated in-memory database, not the
  owner's saved data. Its debug APK compiled, but the test could not start:
  ADB's connection to its local daemon on port 5037 timed out. This is not a
  passing device test. Normal app rebuilding/reopening is tracked separately.
