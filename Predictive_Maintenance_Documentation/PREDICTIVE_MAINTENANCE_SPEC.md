# Maintly / AyosLog — Predictive Maintenance Product & Engineering Specification

**Status:** Implementation specification, not currently implemented. **Version:** 1.0. **Platform:** Flutter/Dart, Riverpod MVVM, Clean Architecture, Drift/SQLite offline-first, optional Supabase/Postgres sync. **Theme:** emerald #17966C light / #26BA88 dark, charcoal #0B0D10 dark background. **Figma:** https://www.figma.com/design/3q0U37sFvN6hEUQpIHqlde

## 1. Scope, terminology, and guardrails

Deliver asset-specific maintenance forecasts with transparent input evidence and editable category forms. Distinguish (1) *preventive*: manufacturer/user scheduled date or usage threshold; (2) *usage forecasting*: estimated date when a known threshold will be reached; (3) *condition alerts*: deviations from supplied measurements or symptoms; (4) *ML prediction*: validated model inference, **not part of initial release**. Never label a fixed threshold reminder as a machine-learning prediction, never claim diagnostic certainty, and never auto-extend a manufacturer-specified safe service interval. An asset's status and a forecast's data quality are separate quantities. Missing data displays “Not enough data,” not a fabricated percentage.

**Who can use it:** Personal owner (v1). Household contributors/viewers only after authorization is implemented (v2). Every observation and forecast belongs to the asset and owner. Avoid collecting unnecessary identifiers or locations.

**MVP order:** Vehicle mileage → air-conditioner hours → water-filter capacity → washer cycles → refrigerator temperature trends → laptop battery trends → optional ML. Every additional category must use the same prediction contract and UI states.

## 2. Information architecture and navigation

**Existing navigation:** Home · Assets · Calendar · Settings. Add **Insights** as a top-level quick action or dashboard destination initially; do not silently change the bottom navigation without testing. Asset Details gains an **Insights** tab; preserve Overview, Service History, Schedules and Documents.

| Screen / route example | Content | Entry points / buttons | Behavior |
|---|---|---|---|
| `/insights` | Counts: on track, due soon, overdue, missing data; grouped recommendation cards | Filter status/category; tap card | Open `/assets/:id/insights/:taskId`; filter affects cards only |
| `/assets/:id/insights/:taskId` | Asset, task, forecast metric/date, status, reliability, progress, rationale, used readings | `Record reading`, `View history`, `Edit maintenance plan` | Opens respective pages with asset/task preselected |
| `/assets/:id/check-in` | Dynamic category form, observed-at date, input source, save | Select metric template; `Save observation` | Validate + local transaction + trigger calculation |
| `/assets/:id/usage-history` | Observations over time, units, source, corrections | `Edit`, `Delete`, `Add reading` | Corrections create audit/recalculation; deleting reading recomputes |
| `/assets/:id/plans/:taskId/edit` | Interval type, interval, manual/manufacturer source, reminder lead | `Save plan` | Validate; invalidate old forecast and recompute |
| `/assets/:id/condition-check` | Category-specific symptom questions | `Submit condition report` | Distinct from numeric telemetry; emit rule-based review flags |
| `/assets/:id/service/new` | Existing service form plus completion metric | `Save completed service` | Store service record and baseline; recompute next due |
| `/insights/missing-data` | Assets without configured plans or readings | `Set up plan`, `Add readings` | Explicit onboarding and empty states |

**Dashboard hierarchy:** Page heading and status summary → due/overdue priority → recommendation cards → missing-data prompts → past resolved notifications. Each prediction card includes asset icon/photo, task, due threshold, status chip, progress bar if meaningful, last reading age, source (‘manufacturer plan’ / ‘owner-defined’), and action.

## 3. Standard interaction / state contract

Every screen supports loading, success, empty, validation error, offline and stale data; destructive actions show confirmation. Recommended prediction states:

- `not_configured`: no task/threshold. CTA **Set maintenance plan**.
- `insufficient_data`: plan exists, but no usable recent measurements for date forecast. Show threshold or calendar reminder only; CTA **Add reading**.
- `scheduled`: fixed calendar due date only; avoid predictive label.
- `estimated`: enough observations and valid positive rate; show **Estimated** with explanation and range.
- `due_soon`: earlier limit within configured warning window (e.g. 7 days or 10% interval remaining), with origin of limit.
- `overdue`: an applicable limit already exceeded. Show **Overdue** and urgent action without diagnosing a fault.
- `condition_alert`: unusual measurement/symptom; display **Review needed**. Condition flags must not change the official due threshold without user/manufacturer confirmation.
- `stale`: last observation older than category-configured freshness threshold; show stale label, last date and check-in CTA.
- `invalid`: impossible or inconsistent input; block forecast and request correction.

**Reliability labels:** `insufficient` (no rate possible), `limited` (few/old readings or variable usage), `moderate` (several consistent observations), never numerical ‘87% confidence’ unless statistically calibrated. Explicitly show sample count, observation date range, source, and assumptions. Do not use an unvalidated “asset health score.”

## 4. Category-specific behavior

Use `CATEGORY_FORMS.md` as the exhaustive field and validation reference; source-of-truth fields are not hardcoded into generic `assets` columns. **Measurement types, units and maintenance tasks vary by category.** Every form includes observation timestamp, measurement source (`manual`, `imported`, `sensor`), nullable notes, a clear `Unknown` option for qualitative observations, units, and confirmation before persisting. Condition and numeric data must be distinct. Users choose schedules from documentation or their own settings; do not bundle unsafe guessed defaults.

1. **Vehicle / motorcycle:** odometer `km` or `mi`, last service reading, service interval and optionally max calendar days. Forecast estimated days to next oil/filter/brake inspection threshold from mileage trend. Irregular usage triggers wider range. Fuel consumption changes and repair recurrence are *review signals*, not diagnoses.
2. **Air conditioner:** daily hours, weekly usage pattern, filter-cleaning timestamp, dusty environment, cooling issues, filter state. Estimate accumulated operating hours and maintenance review threshold; manual hours are estimates, not telemetry.
3. **Refrigerator/freezer:** actual observed internal temperature with units and timestamps, setpoint where known, door-seal status, abnormal sound, recurring cooling issues, last inspection. Detect repeated readings outside user/manual-specified bounds and a drift trend, not “failure likelihood” without sensor/validated failure labels.
4. **Laptop / electronics:** manual/imported battery health percentage, cycle count if available, dates, fan noise/thermal symptoms, battery replacement/repair history. Trend battery metrics over time; warn on regression or anomalies only where consistent and reliable. Do not imply Flutter can read arbitrary laptop telemetry.
5. **Water filter / purifier:** cartridge rated liters, last replacement, estimated daily household consumption (or cumulative meter), optional manufacturer max calendar lifespan, flow observation. Next replacement at *earliest* applicable capacity/time limit, not later.
6. **Washing machine:** cycles logged or estimated per week, last maintenance cycle counter, manufacturer cleaning cycle interval, vibration/leak/sound symptom and service history. Forecast cycles and days to next cleaning/inspection; leaks trigger ‘Review needed’ independently.
7. **Generic/custom asset:** only owner-defined calendar/usage tasks, optional condition notes. No implicit prediction without an appropriate metric or readings.

## 5. Calculation rules — deterministic v1

A task may specify `interval_usage` and/or `interval_days`. Resolve each independently and **take earlier applicable deadline**. For usage thresholds:

```text
usage_target = last_service_usage + interval_usage
usage_remaining = usage_target - latest_usage
usage_progress = clamp((latest_usage-last_service_usage)/interval_usage, 0, 1)
rate_per_day = robust_positive_rate(recent_valid_readings)
forecast_days = usage_remaining / rate_per_day, if rate_per_day > 0
predicted_usage_date = last_observation_at + ceil(forecast_days) days
calendar_due_date = last_service_at + interval_days, if configured
next_due = min(non-null predicted_usage_date, calendar_due_date)
```

**Rate calculation:** Sort at least two distinct timestamped readings ascending; reject impossible negative increments for monotonic counters unless explicitly reset. Convert units to canonical form before calculating. Use `delta_usage / delta_days` across valid observations; prefer median of pairwise daily rates for ≥3 valid readings, optionally 30–90-day time window. Exclude duplicate timestamps and zero-day intervals; never divide by zero. When usage rates are unavailable or zero, show capacity remaining without a date prediction. Do not use the current clock as the start of predicted days unless the latest reading is current; anchor to `last_observation_at` and warn about staleness.

**Window:** optionally derive optimistic/pessimistic bounds from lower/upper quantiles of observed rates; if fewer than 3 intervals or poor variability, show a wide qualitative range or single ‘rough estimate’ instead. Do not call these calibrated probability intervals. Suggested status threshold: due soon if ≤7 days OR ≤10% of configured usage interval, adjustable per task. Overdue if any hard threshold passed. Time and usage threshold must not contradict manufacturer policy.

**Condition alerts (explicit heuristic rules):** Refrigerator: repeated readings outside asset-specific allowed range; increasing median temperature with adequate samples; do not use universal freezer/fridge target as hardcoded guarantee. Laptop: downward trend from timestamped battery-health readings; anomaly alerts require user confirmation and multiple readings. AC/washer: repeated symptom counts in specified rolling window; elevate **Review** without asserting failure. Water flow changes: qualitative review signal, not a direct capacity estimate.

**Cost analytics:** Total service cost in range, rolling monthly average, median by service type (with sample count), anomalous receipt expense flag e.g. above user-configured threshold or robust median-based deviation only with enough comparable records. Costs are not predictive failure indicators without evidence.

**Completed maintenance:** Save the service event first, snapshot the completion reading and timestamp, update applicable task baseline atomically, invalidate affected forecast, calculate next due, schedule new reminder. Retroactive service entry requires explicit policy: baseline from actual service date/reading, not the date of data entry. Editing/cancelling a service recalculates associated forecasts and preserves history.

## 6. Concrete worked examples

**Motorcycle:** last oil change 8,000 km, interval 2,000 km (illustrative only), current reading 9,450 km, rate 210 km/week. Target=10,000 km, remaining=550 km, rate=30 km/day, forecast ≈18.3 days from current reading date. Add manufacturer calendar limit if present; earlier wins.

**AC:** user estimates 8 h/day for 35 days since inspection ≈280 h. A task set for 300 h would have ≈20 h remaining; at 8 h/day about 2.5 days (if usage persists). Label **estimated hours**.

**Filter:** 2,000 L rated capacity, 12 L/day estimated, 45 days since replacement → about 540 L consumed, 1,460 L remaining, ≈122 days at same rate. If manufacturer time limit is sooner, that limit wins.

**Washer:** 35 cycles since last maintenance, 7 cycles/week, owner-configured 50-cycle interval → 15 cycles remaining ≈15 days. No actual usage sensor is presumed.

**Refrigerator:** four manually logged internal-temperature readings trend upward; generate ‘Review temperature trends’ only if outside configured model/user bounds or meets repeated anomaly rule. Never diagnose a refrigerant problem.

**Laptop:** multiple dated battery-health percentages decreasing over months → show trend and recommend checking manufacturer diagnostics; never automatically declare replacement time from an unvalidated extrapolation.

## 7. UI visual spec (both modes)

**Reference:** The current Figma color system and `DESIGN.md` are authoritative; do not copy unrelated UI design rules from a different project. Page background Light `#F4F6FA`, Dark `#0B0D10`; surfaces `#FFFFFF` / `#1C1F24`; raised inputs `#EFF2F6` / `#292C32`; brand `#17966C` / `#26BA88`; main text `#192536` / `#F3F5F7`; secondary `#778294` / `#9FA6B0`; outline `#E5EAF0` / `#353941`. Warning is amber, error red, information blue. Keep statuses accompanied by text/icons. Hero cards radius 22–24, CTAs/fields radius 16, pills fully rounded, floating bottom nav radius ~29. Inter font; semantic text styles, never scattered inline hex codes. Minimum tap target ~48 dp, dynamic text scaling and screen-reader labels.

**Dashboard layout:** app bar → summary (counts, no fabricated health score) → active filter chips → prioritized cards → missing data notice → bottom nav. **Asset insight:** app bar → asset identity → primary prediction/remaining usage → progress bar → estimated date/range with badge → “Why this estimate?” bullet evidence → last-reading age/reliability → `Record reading` primary CTA → `View service history` secondary. **Check-in:** category header → repeatable numeric/qualitative sections → observation date/source → inline validation → sticky `Save observation` CTA with loading/duplicate submit prevention. **States:** empty, offline, permission denied, stale, invalid input, completed. Dark screens have identical information hierarchy, not just inverted text.

## 8. Calculation lifecycle and offline sync

Local Drift tables are canonical on device; treat forecast rows as **derived/cacheable**, not authoritative raw evidence. Recalculate on: observation created/edited/deleted, task changed, service recorded/corrected, asset category/unit changed, sync conflict reconciliation, and (optionally) on app resume when stale. Use deterministic engine `rules_v1`, record `calculated_at`, `based_on_latest_observation_id`, task policy version, and input snapshot. Never silently alter the underlying user readings. Save user-entered records through domain use cases and repository boundaries; no SQL in widgets.

Supabase mirrors owner-scoped observations, plans and service events; predictions may be recomputed locally and do not require a cloud prediction table in MVP. Offline changes enqueue outbox entries. Stable IDs, conflict policy (server version/user correction), idempotent upsert, and ownership RLS are required before multi-device sync. A device's local data for one account must never leak into another's login.

## 9. Acceptance criteria

- Every category form renders only applicable fields, with `Unknown` and units where needed; required fields are enforced appropriately.
- New asset with no plan → `not_configured` and CTA; plan without observations → `insufficient_data`/`scheduled`; no fake forecast.
- Duplicate dates, negative interval, odometer regression, zero rates, implausible readings, swapped units, stale data are handled without crashes.
- Any configured time-based limit may take precedence over usage-based forecast.
- Completing/editing/deleting service correctly recalculates due information and preserves audit trail.
- Forecast explanation shows source, exact readings, formula/policy version and reliability; no unvalidated percentage.
- Widget/golden checks in both theme modes; domain unit tests for category calculations; Drift migration and repository tests.
- User can make observations and inspect forecasts offline. RLS and authenticated ownership verified before cloud deployment.

## 10. Non-goals, disclaimers and backlog

Not medical/safety diagnostics; no automatic equipment sensor readings unless separately integrated; no generic failure-risk percentage; no hidden LLM diagnosis; no reliance on arbitrary brand/model maintenance intervals. Future optional additions: manufacturer-document ingestion with human verification, supported IoT integrations, validated ML based on labeled failures, seasonality, shared households, and CSV export. Treat all outputs as maintenance planning support, with explicit reference to manufacturer instructions.
