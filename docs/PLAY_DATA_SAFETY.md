# Play Console — Data Safety Form Mapping

Reference for filling out Play Console's **App content → Data safety** questionnaire. Written
from the current codebase (2026-08-04) — re-check before submitting if data flows change
(new tables, new third-party SDKs, new upload paths). Verified by grepping `lib/` for any
`storage.from(...)`/`.upload(...)` call (Supabase Storage) and any analytics SDK import — neither
exists, which is why camera data below is marked "collected but not shared/uploaded."

## Does your app collect or share any of the required user data types?
**Yes.**

## Data types collected

### Location
- **Precise location** — collected. Source: `geolocator` (foreground-only, while-in-use; see
  `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, no `ACCESS_BACKGROUND_LOCATION`).
- **Purpose:** App functionality (run tracking, territory capture), Analytics (none — not used
  for analytics).
- **Shared with third parties:** No. Sent only to your own Supabase project (`runs`, `territories`,
  `active_runs` tables) via `submit_run()`/related RPCs — Supabase is a service provider processing
  data on your behalf, not a third party for this form's purposes (declare it under "data
  processed by a service provider" if the form's current version asks, not "shared with third
  parties").
- **Processed ephemerally:** No — persisted (needed for territory features to function).
- **User can request deletion:** Yes — account deletion (`delete-account` Edge Function) removes it.

### Photos / Videos (Camera)
- **Camera images:** collected, but **not shared, not uploaded, not persisted.** ML Kit pose
  detection (`google_mlkit_pose_detection`) processes camera frames entirely on-device
  (`pose_verification_repository_impl.dart`) to detect exercise reps; frames are never written to
  disk, sent to Supabase, or sent to any third party. In the Data Safety form: mark **collected:
  No** for Photos/Videos if the form's definition of "collected" is "transmitted off device"
  (it generally is) — camera frames never leave the device. If declaring conservatively, mark
  "collected" with **purpose: App functionality**, **not shared**, **ephemeral (not saved)**.

### Personal info
- **Email address** — collected via Supabase Auth (email/password linking) and Google Sign-In.
  Purpose: Account management. Not shared with third parties beyond the auth provider
  (Google, as an OAuth identity provider the user explicitly chose) and Supabase (service
  provider).
- **Name** — optional, from Google Sign-In profile / `profiles.display_name`. Purpose: App
  functionality (shown to squadmates on leaderboards).
- **User IDs** — Supabase `auth.uid()`, used for all data ownership/RLS. Purpose: App
  functionality, Account management.

### Health and fitness
- **Fitness info** — workout completion (squats/push-ups reps, exercise mode), run
  distance/duration/route. Purpose: App functionality. Not shared with third parties. Note: Play
  Console treats "Fitness info" as a **sensitive category** — expect an extra declaration step
  (why it's collected, whether it's optional).

### App activity / App info and performance
- **Crash logs / diagnostics** — Sentry (`sentry_flutter`), with `beforeSend`/`beforeBreadcrumb`
  scrubbing GPS coordinates and camera-frame data before transmission (see `main_common.dart`).
  Purpose: App functionality (crash reporting). **Shared with third parties: Yes** — Sentry is a
  third-party crash-reporting service; declare it as such (not just "service provider") since
  Sentry may retain/process data under its own terms, not purely as your data processor extension
  — check Sentry's DPA if the form's distinction matters for your answer.

### What's explicitly NOT collected
- No advertising ID (no ads SDK in `pubspec.yaml`).
- No analytics SDK (Firebase Analytics, Mixpanel, Amplitude, etc. — none present).
- No financial info, no messages/SMS, no contacts, no calendar, no files/docs beyond the local
  Drift DB (never uploaded as a file).

## Security practices section
- **Data encrypted in transit:** Yes (Supabase enforces TLS; Sentry DSN over HTTPS).
- **Data encrypted at rest:** Yes (Supabase/Postgres default; standard cloud-provider disk
  encryption — confirm current Supabase project settings if asked for specifics).
- **Users can request data deletion:** Yes — in-app account deletion goes through
  `delete-account` Edge Function.
- **Committed to Play Families Policy / independent security review:** No (not applicable —
  this app is not targeted at children; do not check "Designed for Families").

## Before submitting
1. This doc is a **starting draft**, not a substitute for actually reading each Play Console
   question — the questionnaire's exact wording and category boundaries change over time.
2. If you add any new third-party SDK (ads, analytics, a new backend) or any new upload path
   (e.g. profile photo upload to Supabase Storage), update this doc and the in-app Privacy Policy
   (`docs/PRIVACY_POLICY.md` / `docs/privacy-policy.html`) together — Play cross-checks the
   declared data types against what reviewers observe the app actually doing at runtime.
3. Camera/location purpose strings in the questionnaire should match the runtime permission
   rationale text shown in-app (onboarding, first camera/location prompt) — mismatches are a
   common rejection reason.
