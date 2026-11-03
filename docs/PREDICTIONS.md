# Task-specific maintenance recommendations

## Acceptance criteria

- Every maintenance task chooses its own measure: elapsed time, operating hours, cycles, pages, litres, observed condition, or car mileage. Different tasks and components may use different measures on the same asset.
- Mileage is offered only after a vehicle is explicitly marked as a car. Migration never guesses which vehicles are cars; legacy mileage records remain stored.
- Sources are shown separately: service-history estimate, user-defined interval, and manufacturer guidance entered by the user. Manufacturer inputs require a model/manual reference; AyosLog does not independently verify that reference or supply universal model intervals.
- Entered manufacturer usage/time limits cap longer user/history intervals. The earlier available usage-projected date or time-based date is shown. A missing usage projection does not hide an applicable time limit.
- History averages need at least 3 comparable routine/inspection services. Repairs do not teach routine intervals. Numeric intervals use the latest consecutive sequence with usage; gaps do not bridge an unmeasured service. Time estimates use actual completion dates. Service readings are dated usage observations too.
- A usage projection requires positive, non-decreasing cumulative readings spanning at least 7 days inside a 90-day window ending at the latest reading. The recorded date is always shown. Missing/stale data is never converted into an invented current counter.
- Condition checks store No concern observed, Watch / monitor, or Needs attention and optional notes. They are user observations, not automatic failure predictions. New checks are required after later service work.
- Cost comparisons use the same asset, component, task and service type. A latest positive cost over 1.5 times the mean of at least 3 earlier positive costs is flagged; baseline/count/threshold are visible. Cost increases are not a diagnosis.
- Rules, counters and observations persist locally. A task's identity/component/unit cannot change in place and mix old measurements. Source and limits can be edited; a different measure requires another task.
- Forms have validation, duplicate-submit protection, loading/empty/error/retry states and both themes. Task counters accept whole counts for km/cycles/pages and decimals for hours/litres. Backdated readings must fit surrounding readings for that task. Car mileage also respects the asset odometer history.
- Schema v3 preserves v1/v2 assets, plans, service history and mileage. Service, usage reading and linked recurrence updates commit or roll back together. Archived assets retain their history.
- No illustrative records are inserted into the real database. No failure probability, diagnosis or machine-learning accuracy is claimed.

## Using the feature

The form uses plain-language labels: What needs to be done? (job name), Which part? (optional), Remind me based on (days, hours, uses, pages, litres, distance or a check), and Base the timing on (past records, your own timing or the product manual). Examples explain each choice. A running total keeps adding new use to the previous total, such as 100 + 5 = 105; this arithmetic example is not a suggested maintenance interval.

Open an asset and choose Add maintenance reminder. Enter the task/component, choose its measure and source, and enter any applicable limits and reference. To enable car mileage, explicitly mark a vehicle as a car in this form. Home previews recommendations for all asset categories.

When recording maintenance, select the configured task. Numeric tasks show only their own usage field; enter total cumulative usage at the service date, or leave it blank if unknown. Time-only tasks use completion dates. Repairs remain in history and cost comparisons but do not establish a routine completion baseline.

Use Update total / Update distance for a numeric task, or Add a check for an observation task. Keep numeric counters cumulative; do not reset them after service. The latest recorded values and dates appear on the recommendation. Existing unconfigured service tasks offer Set up a reminder; no usage measure is inferred from their free text.

## Architecture and storage

Domain entities, validation and rules are pure Dart. Riverpod StateNotifiers own presentation state. The repository maps Drift rows and enforces transactional invariants using domain validators. Widgets do not issue SQL. The existing OCR integration seam is unchanged: extracted text remains editable and never supplies a guessed cost or usage value.

The legacy mileage route/class remains for old deep links, but its form is task-specific. Task rules and new readings have their own tables. v2 odometer records are preserved and reused only for an explicitly configured car-mileage task.

## Verification

Tests cover all metrics, source labels, manufacturer ceilings, earlier-date selection, task/component/asset isolation, repair exclusion, observations, invalid input, duplicate submits, v1/v2 migration, restart persistence and rollback. Light/dark widget tests cover forms and recommendation states, including large-text layouts. Android integration tests use isolated temporary databases for car and non-car flows. iOS and release/store verification remain outside these checks.

## Research basis

The approved design was informed by manufacturer documentation on [Honda operating-hour/time schedules](https://cdn.powerequipment.honda.com/pe/pdf/manuals/00X31Z456030.pdf), [Bosch wash-cycle reminders](https://www.bosch-home.co.uk/experience-bosch/using-your-appliance/washing-machine-symbols-guide), [Daikin filter maintenance](https://www.daikin.com/products/ac/services/maintenance_tips), [Brother page-based drum life](https://help.brother-usa.com/app/answers/detail/a_id/125013/~/replace-drum-message), and [Brita volume/time guidance](https://www.brita.com/support/faq/replacement-filters/). These examples inform supported measures; their product-specific intervals are not automatically assigned to user assets.
