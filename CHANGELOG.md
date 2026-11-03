# Changelog

- Restore category-specific asset setup and completion fields to the normal
  forms, persist setup metadata, and retain CATEGORY_FORMS.md as the contract.
- Repair service loading/category-change failures on early v5/v6 databases and
  the Future-returning setState callback when refreshing an asset.
- Add two-step asset creation with Set maintenance plan, Skip, saved repeat/date/
  reminder settings and category-specific plan options.
- Show asset headings with service type/date below on upcoming maintenance cards.

- Add the local `rules_v1` predictive maintenance module: typed category forms,
  Insights, per-task evidence, usage/condition check-ins, trends, cost summaries,
  reading corrections, service completion/correction/cancellation and audit.
- Add Drift schema 5 for forecast source evidence/policies/derived snapshots;
  regenerate Drift code to resolve new column/table getter errors.
- Add schema 6 and seven asset categories from CATEGORY_FORMS.md; retain original
  broad labels and service history, support category selection on existing assets.
- Add calendar forecast dates and Home/Asset Insights entry points without
  changing the four bottom destinations. OS notifications and cloud sync remain
  unimplemented.

## Unreleased

- Load reference UI test fonts from licensed, checked-in fixtures instead of Flutter's internal SDK cache, and await file reads before registering fonts.

- Fix the GitHub formatting check for receipt tests and replace the invalid preview PNG fixture with a generated image that is loaded before assertions in both themes.

- Make Asset details sections expand/collapse smoothly within the page, retain their content state, and remove expanded/collapsed divider borders.

- Restyle asset and maintenance forms, asset details, calendar and service record details using the supplied visual references in both themes; center primary button labels and keep form actions visible.
- Keep bottom navigation on asset/service routes and retain immediate push/back transitions. Add neutral date selection and functional calendar scheduling.
- Save performed-by metadata with an additive v3-to-v4 database migration and expose service details/receipt viewing through ViewModels.
- Fix the invalid const spinner wrapper in `AppButton` when selecting a theme-dependent loading color.

- Simplify reminder setup with plain-language questions, job/part examples, everyday usage choices and running-total guidance.

- Replace the mileage-only recommendation workflow with task-specific time, hours, cycles, pages, litres, condition observations and explicitly enabled car mileage.
- Add user/history/manufacturer-reference sources, manufacturer ceilings, earlier time/usage dates, component/type-specific cost baselines, and repair exclusion from routine forecasting.
- Add schema v3 with lossless v1/v2 migration, immutable task measures, task settings and generic usage forms; show recommendations across all asset categories.

- Use a temporary debug-only Skia renderer workaround for repeated Mali/Vulkan format allocation errors on the test Android phone; keep release renderer defaults.

- Add rule-based maintenance recommendations with task-specific average mileage intervals, remaining distance, usage-based estimated dates, and unusually high cost flags against the asset's own task history.
- Add dated odometer readings and optional task/mileage fields on service records, with validation, duplicate-submit protection, and reactive cards on Home (vehicles) and asset details.
- Migrate local schema v1 to v2 without inventing values for existing service records; retain atomic service, mileage, and linked recurrence writes.

- Use neutral light/dark calendar pickers instead of green accents, and remove checkmarks from Assets category pills.

- Align multiline field labels and text to the top.
- Preserve full OCR text and original photo resolution; handle empty scans without clearing notes and prevent overlapping scans or saving mid-scan.
- Add the iOS photo-library usage description for receipt selection.
- Add OCR flow regression tests and a native recognition smoke test, verified on Android with a clean synthetic receipt.

- Remove slide transitions from tab changes and pushed pages while preserving back navigation.
- Keep category, recurrence, and service dropdown menus within the field width and open them below the field when space permits.
- Match dropdown fields and menus to the themed text-field background in light and dark mode.
- Center Assets and Calendar empty states with themed icons above their messages; show search guidance when asset filters have no matches.
