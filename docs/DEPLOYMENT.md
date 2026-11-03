# Local setup, Supabase database, and production deployment

> This package is a **functional offline-first MVP scaffold**, not a release-certified production build. It needs native project generation, code generation, dependency resolution, device QA, release signing, and cloud integration before public launch.

## 1. Windows developer setup
1. Install Flutter SDK (stable), Android Studio, Android SDK and VS Code Flutter/Dart extensions. Add Flutter `bin` to PATH.
2. In PowerShell: `flutter doctor -v`, fix all Android toolchain issues; `flutter doctor --android-licenses`.
3. Unzip and open `AyosLog` in VS Code. Run `flutter create --platforms=android,ios .` to generate missing platform directories (iOS builds require macOS/Xcode).
4. `flutter pub get`
5. `dart run build_runner build --delete-conflicting-outputs`
6. `dart format lib test`
7. `flutter analyze`
8. `flutter test`
9. Connect emulator/device, `flutter run`.

## 2. Create your Supabase database
1. Open https://supabase.com/dashboard and create a **new project** called `ayoslog-dev` in a suitable region; use a unique generated DB password stored in a password manager.
2. Dashboard → **SQL Editor** → New query. Open `supabase/migrations/0001_initial.sql` from this archive and paste it, then Run. This is a starter migration for a fresh project.
3. Dashboard → **Database → Tables**: verify profiles, assets, plans, events, documents, readings, reminders, change log.
4. Verify RLS is enabled and ownership policies exist for each table. Test with at least **two** users; user A must never see user B's records. Check SQL editor context (admin bypasses RLS, so SQL editor success does not prove policies).
5. Dashboard → Authentication → Providers: enable email auth and configure email verification/callback URLs appropriate to your mobile app.
6. Create a **private** Storage bucket for asset documents; configure owner-scoped policies before uploading any receipt. Do not use public buckets for customer documents.
7. Project **Connect** panel → copy Project URL and publishable key. They are for the future cloud adapter, not yet consumed by this offline MVP. Do not copy database password or service_role into Flutter.
8. Before production, follow `SECURITY.md`: cloud starter schema needs ownership immutability, server-side versions, profile provisioning and secure sync RPCs. No client-side sync included in this MVP.

## 3. Add cloud integration (required before calling it cloud-ready)
1. Implement `AuthRepository` and auth screen; initialize Supabase using URL/publishable key passed via `--dart-define`.
2. Create user profile after verified login; use RLS to scope ownership.
3. Build `RemoteAssetDataSource` and explicit `sync_outbox` stored in SQLite, transactionally populated on every local change.
4. Implement idempotent upload, pull cursor, server revision checks, conflict UI and safe retry.
5. Implement Supabase Storage policies for receipts, persistent local file copies, and signed upload/download.
6. Write integration tests including offline-to-online conflicts and permission denial.

## 4. Android internal release
1. Configure a unique applicationId (e.g. `com.yourstudio.ayoslog`), app title/icons and target SDK in generated Android files; do not leave default identifiers.
2. Set required INTERNET and any camera/media permissions after reviewing packages and Play policies.
3. For OCR, check current Google ML Kit platform minimum SDK/OS requirements and validate on physical devices.
4. Create Android upload keystore and configure Gradle signing without committing secrets or `key.properties`.
5. Run tests: `flutter analyze`, `flutter test`, and device tests in both themes and while offline.
6. Build: `flutter build appbundle --release` (or `flutter build apk --release` for private testers). Output: `build/app/outputs/bundle/release/app-release.aab`.
7. Open Google Play Console → create app → fill store metadata, screenshots, privacy policy, Data Safety, content rating, target audience; upload AAB to **internal testing** first.
8. Resolve crashes, layout problems, and Play policy warnings before production rollout; increment `version` in pubspec for releases.

## 5. iOS later
macOS + Xcode + Apple Developer Program, configure signing, bundle ID, privacy keys for image library, deployment targets for OCR, TestFlight, App Store Connect and privacy details. Use Flutter's official iOS deployment guide.

## 6. Production release checklist
- [ ] All builds/tests pass against a pinned `pubspec.lock`
- [ ] Real device tested Android and iOS; text scaling and accessibility
- [ ] Data loss / SQLite migration tests and backup plan
- [ ] Account flows, RLS, cloud sync and storage security if enabled
- [ ] Persist receipt files into app-private storage and cleanly delete them
- [ ] Notifications permission and scheduling verified
- [ ] Crash reporting, privacy policy, export/delete process
- [ ] CI build/signing secrets securely stored
- [ ] Internal beta and rollback strategy

Official guides: https://docs.flutter.dev/deployment/android , https://supabase.com/docs/guides/getting-started/quickstarts/flutter
