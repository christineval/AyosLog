# Security and privacy

**Offline scaffold:** No account system is implemented. All records are stored locally on the device. A device with unlocked access may expose them. Do not claim multi-user isolation or encrypted-at-rest storage.

**Before enabling Supabase:**
- Use publishable/anon key only in mobile. Never bundle service_role key, database connection URL, signing secrets, or API admin credentials.
- Enable RLS on every owned table and test read/write denial between two authenticated users.
- Cloud migration is starter-only: harden ownership immutable columns, consistent asset→plan/event ancestry, trusted version increments, profile provisioning and server-generated change log before launch.
- Use private Storage buckets with object-level owner policies and short-lived access; never public receipt URLs.
- Decide data retention/export/delete policy; exclude sensitive OCR images from logs and crash payloads.
- Keep SQL migrations version-controlled; rotate compromised credentials.
- Set release app ID, email-verification callbacks, safe deep links, platform entitlements and privacy policy.

**Threat checks:** unauthorized access via guessed asset IDs; malicious payloads in OCR; lost phone; out-of-date sync conflicts; race conditions on service completion; attachment content/type spoofing; leaking credentials through app build config.
