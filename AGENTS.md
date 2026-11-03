# AyosLog — Rules for AI coding agents and contributors

## Read first
1. `README.md` for scope and setup.
2. `DESIGN.md` for light/dark tokens and shared widgets.
3. `docs/ARCHITECTURE.md` for inward dependency rules.
4. `docs/DATABASE.md` for source-of-truth and schema.
5. `docs/SECURITY.md` before any cloud/auth/storage implementation.

## Non-negotiables
- Use **feature-first Clean Architecture + MVVM**. Widgets are Views; Riverpod StateNotifiers are ViewModels; use cases hold business rules; repositories isolate persistence.
- Presentation must not issue SQL, construct Supabase queries, or call OCR platform APIs directly when building new features. Existing OCR screen is a v0.1 integration seam to refactor into a document service.
- Domain must be pure Dart: no Flutter UI, Drift or Supabase imports.
- SQLite/Drift is local source of truth. Do **not** label the app synchronized until an outbox, conflict handling, retry and server security are implemented and tested.
- Do not place `service_role` or any secret in the app bundle. Supabase publishable key is client-safe only with correct RLS.
- Every new feature needs explicit loading/empty/error states, form validation, duplicate-submit protection, tests and both themes.
- Never introduce hardcoded emerald/charcoal colors in features; use `Theme.of(context)` / `AppColors` / shared widgets.
- Archiving assets should not delete service history. Recording a service and updating a linked recurrence belong in one transaction.
- OCR is untrusted: show extracted text for user correction, never silently save guessed totals.
- Do not imply ML forecasts are safety-critical predictive diagnosis.
- Do not claim deployable until `flutter analyze`, `flutter test`, Android/iOS platform setup, release signing, RLS tests and device QA pass.

## Workflow
1. Define feature acceptance criteria and screen states.
2. Add/adjust domain entity and use case.
3. Add repository contract, data implementation and migration.
4. Add ViewModel + providers; keep widget effects minimal.
5. Build using themed components; test light/dark.
6. Add unit/widget/integration tests.
7. Update docs and changelog.

## Commands
`flutter create --platforms=android,ios .` (run once to generate native scaffolding)
`flutter pub get`
`dart run build_runner build --delete-conflicting-outputs`
`dart format lib test`
`flutter analyze`
`flutter test`
`flutter run`

## Definition of done
All commands pass locally; no embedded secrets; device tested; migrations tested from prior version; user data survives restart; accessibility checked; Store checklists complete.
