# Category-specific Dynamic Form Contracts

**Implementation rule:** Build forms from typed field definitions (`id`, `label`, `type`, `unit`, `required`, `validation`, `visibility`, `helpText`). No magical category-dependent widget conditionals scattered throughout pages. Persist numeric readings in canonical units; show display units per user preference. Every entry stores `recorded_at`, `source: manual|imported|sensor`, optional `note`, and owner/asset association. Use `Unknown / Not checked` in qualitative fields. Distinguish configuration, recurring check-in and completed-service forms.

## 1. Vehicle / Motorcycle (`vehicle`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Asset setup | `vehicle_type` enum motorcycle/car/other; `make_model` text | Optional subtype/model |
| Plan | `task_type` enum oil_change, tires, brake_inspection, custom | Required, task-specific |
| Plan | `interval_distance` decimal + `distance_unit` km/mi | >0 if distance-based; source manufacturer/user |
| Plan | `interval_days` integer | Optional; >0; earliest applicable threshold wins |
| Plan | `last_service_odometer` decimal | Required for distance-based plan; nonnegative |
| Check-in | `odometer` decimal + unit | Required; monotonic unless reset recorded; precision sensible |
| Check-in | `recorded_at` datetime, `usage_note` text | Required timestamp, not future beyond small clock tolerance |
| Condition | `fuel_efficiency` decimal (optional), `unusual_noise` enum, `warning_lights` bool/unknown | Optional, review-only flags |
| Service completion | `service_odometer`, `service_date`, cost, attachments | Usage baseline for selected task; may be earlier than entry time |

**Show:** next target odometer, distance remaining, estimated reach date if rate exists, calendar due if specified, earlier deadline, evidence list, last reading freshness. **Rate:** robust km/day; at least two chronological readings. **Warnings:** regression, distance-unit conversion, unusually high increment review. Never infer oil intervals from vehicle name.

## 2. Air Conditioner (`air_conditioner`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Setup | `ac_type` enum split/window/central/portable | Optional |
| Plan | `task_type` filter_inspection, coil_inspection, custom | Required |
| Plan | `interval_hours` positive decimal, `interval_days` optional | Manufacturer/user source; earlier limit wins |
| Usage | `hours_per_day` decimal 0..24, `days_per_week` integer 0..7 | Manual estimate; both needed for rate-based estimate |
| Usage | `operating_hours_total` decimal (optional) | Actual meter reading if available; monotonic |
| Condition | `dust_exposure` normal/high/unknown; `cooling_performance` normal/weaker/unknown; `filter_condition` clean/dirty/unknown | Optional, reviewed as separate signals |
| Service completion | `cleaned_at`, `meter_hours_at_service` optional | New baseline |

**Estimate:** `hours_per_day * days_per_week / 7` if no meter; elapsed since service × usage estimate; revise when reported usage changes. **UI:** “Estimated operating hours,” never “device-reported hours.” Do not label dust exposure as failure probability.

## 3. Refrigerator / Freezer (`refrigerator`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Setup | `equipment_type` fridge/freezer; `model` text | Optional, type required |
| Plan | `task_type` temperature_check, seal_inspection, custom; `interval_days` positive | Required |
| Configuration | `min_expected_temp`, `max_expected_temp`, `temp_unit` C/F | Optional, model/manual-derived; enforce min < max |
| Check-in | `internal_temp` decimal and unit, `recorded_at` datetime | Numeric reading if checking temperature, sensible plausibility bounds and outlier confirmation |
| Condition | `door_seal` good/worn/unknown; `noise` normal/unusual/unknown; `cooling_issue` yes/no/unknown | All optional; unknown explicit |
| Service | `service_date`, issue, action, cost | Baseline for inspection task |

**Trend:** require ≥3 readings across distinct dates to show direction, identify ≥2 readings beyond configured bounds before recurring warning, and show measurement source. **UI:** plot readings + configured safe range; “Review repeated unusual temperatures,” not diagnosis. Without configured range, show chart without universal red threshold.

## 4. Laptop / Electronics (`laptop`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Setup | `device_type` laptop/tablet/other, `manufacturer_model` | Required type; model optional |
| Plan | `task_type` battery_health_check, cleaning, custom; `interval_days` | Optional if only tracking condition |
| Check-in | `battery_health_pct` decimal 0..100, `cycle_count` nonnegative integer optional | At least one measurement; source manual/imported |
| Condition | `overheating` never/sometimes/often/unknown; `fan_noise` normal/unusual/unknown; `performance_issues` yes/no/unknown | Optional review flags |
| Service | `battery_replaced` bool, `service_date`, cost | A battery replacement resets health trend baseline |

**Trend:** show readings across time, slope over 30/60/90 days only with sufficient dated data; avoid predictions of exact battery failure/replacement date without validated model and guidelines. Don't advertise platform-wide laptop metrics via Flutter.

## 5. Water Filter / Purifier (`water_filter`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Setup | `filter_model` text, `household_size` integer optional | For context only |
| Plan | `rated_capacity_liters` >0 decimal, `max_service_days` optional >0 | Manufacturer-sourced or user-entered with source |
| Usage | `liters_per_day` decimal ≥0 (estimate) OR `cumulative_meter_liters` decimal | One usage method required for forecast; prohibit mixing without conversion |
| Condition | `flow` normal/reduced/unknown; `taste_or_odor_change` yes/no/unknown | Review-only, not proof of safety |
| Service | `replacement_date`, `meter_liters_at_change` optional | Reset replacement baseline |

**Estimate:** remaining liters = capacity − estimated consumption since replacement, or meter delta. Date = latest observation + remaining / daily consumption if >0. Time-based max lifespan wins when earlier; never use estimate to extend safe limit.

## 6. Washing Machine (`washing_machine`)

| Context | Field key / type | Validation / visibility |
|---|---|---|
| Setup | `washer_type` front_load/top_load/other | Optional |
| Plan | `task_type` drum_clean, filter_clean, inspection, custom | Required |
| Plan | `interval_cycles` positive integer, `interval_days` optional | At least one interval |
| Usage | `cycles_per_week` ≥0 decimal (estimate) OR `lifetime_cycle_counter` monotonic int | One method per task; clearly estimated vs measured |
| Condition | `vibration` normal/high/unknown, `leak` yes/no/unknown, `noise` normal/unusual/unknown | Leak or high vibration prompts review, not diagnosis |
| Service | `service_date`, `cycles_at_service` optional | Baseline reset |

**Estimate:** days = remaining cycles ÷ (cycles/week ÷ 7) if positive. With no positive rate, show cycles remaining only. Use manufacturer schedule for cleaning.

## 7. Custom / Other (`custom`)

Fields: task name, schedule type calendar/usage, usage metric label and unit, starting reading, configured interval, reading value, observed at, notes. No predictive date for usage type unless two reliable dated observations or user explicitly supplied usage/day estimate. Prevent negative intervals, missing unit, incompatible historical readings.

## Shared widgets and validation

- `CategoryFormRenderer`: receives typed template + values; renders shared `AppTextField`, `AppDropdown`, `AppDatePicker`, `AppSegmentedControl`, `AppConditionSelect`.
- `MetricValueField`: number + fixed unit selector, unit conversions on save; do not allow arbitrary strings in numeric columns.
- `MeasurementSourceField`: Manual / Imported / Sensor, with sensor only if integration present.
- `ObservedAtField`: user-local date/time stored UTC; future date validation.
- `FieldHint`: source, data privacy, example reading, and measurement instructions.
- `ValidationSummary`: field-specific errors and accessible screen-reader messages.
- `SubmitButton`: disabled while saving, confirmation after persistence, safe retry on offline error.

**Generic asset category vs subtype:** Existing project may store `appliance`, `electronics`, `vehicle`, `home`, `other`. Add `asset_subtype` mapping `air_conditioner`, `refrigerator`, `washing_machine`, `laptop`, `water_filter`, etc. Avoid breaking current category filters or migrating category enum without a plan.
