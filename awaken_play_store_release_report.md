# Awaken — Google Play Store Release Report
*Generated 2026-08-04*

## 1. Bottom line

The app is **close but not ready** to submit. Nothing found is a deep architectural blocker — the
gaps are packaging/store-listing/compliance items plus a couple of small code cleanups. Given your
Play Console account is a **new personal account**, the biggest schedule driver isn't code — it's
Google's closed-testing requirement (see §3).

---

## 2. Codebase audit findings

### Signing & build config (`android/app/build.gradle.kts`)
- `applicationId`: `com.awaken.alarm.v1`, `compileSdk`/`targetSdk` = **36** (Android 16) — already
  ahead of the Aug 31, 2026 target-API deadline. `minSdk` = 26.
- `versionCode`/`versionName` come from `pubspec.yaml`'s `version: 0.1.0+3` → versionName `0.1.0`,
  versionCode `3`. Fine for a first upload; Play just needs any versionCode ≥ 1 you haven't used
  before on that applicationId/track.
- A real release **signing config exists and is active**: `android/key.properties` +
  `android/upload-keystore.jks` are present on disk, correctly gitignored, not committed. Good —
  this is exactly the "upload key" Play Console's App Signing expects.
  ⚠️ **Action needed from you**: back up `upload-keystore.jks` and the keystore password somewhere
  safe outside this repo (password manager / offline). If lost, you cannot push updates to an
  existing Play listing without going through Google's key-reset support flow.
- `isMinifyEnabled = true`, `isShrinkResources = true` — R8/resource shrinking is on for release,
  and `proguard-rules.pro` was just expanded (uncommitted change) with `-keep` rules for
  WorkManager/Room, Drift, Sentry, Ktor/OkHttp/Okio, kotlinx.serialization, and Flutter's own
  plugin registrant. This looks like a real, recent fix for a `WorkDatabase` R8-stripping crash —
  **you must do one real signed-release build-and-smoke-test** after this (see §5) before
  submitting, since minified release behavior can diverge from debug.
- `dev`/`prod` flavors correctly split by `applicationIdSuffix`; only `prod` (no suffix) should go
  to Play.

### Manifest / permissions (`AndroidManifest.xml`)
- Declared: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
  `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION`/`_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`,
  `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`,
  `RECEIVE_BOOT_COMPLETED`, `INTERNET`.
- `ACCESS_BACKGROUND_LOCATION` correctly **absent** by design (CLAUDE.md H3) — avoids Play's
  strictest background-location review tier. Keep it that way.
- Foreground service correctly typed (`foregroundServiceType="location"`) and `exported="false"` —
  meets the Android 12+/14+ requirement.
- These permissions all need matching declarations in Play Console's **Data safety** form and,
  for exact alarms + full-screen intent, a justification (the "alarm clock" core-functionality
  exemption should apply — declare it explicitly, don't assume it's automatic).

### App icon
- Real custom adaptive icon (`launcher_icon.png` + `ic_launcher_foreground.png`) is wired up via
  `android:icon="@mipmap/launcher_icon"`. **Minor cleanup**: stock Flutter default `ic_launcher.png`
  files (400–1400 bytes, from the original `flutter create`) still sit unused in every
  `mipmap-*dpi/` folder — delete them, they're dead weight, not a blocker.

### Secrets
- No leaked private keys/service-role keys/`sk_live` style secrets in tracked files.
- `google-services.json` / `GoogleService-Info.plist` contain Firebase `AIza...` keys — this is
  normal (they're restricted by package name + SHA-1 fingerprint, not secret), but **confirm in
  Google Cloud Console that API key restrictions are actually configured** before shipping, since
  an unrestricted Firebase key is a real (if often overlooked) risk.
- `.env.client` (tracked) intentionally holds only the public Supabase anon key — correct per your
  documented two-file env split.

### Privacy policy
- `docs/privacy-policy.html` (268 lines, dated Aug 1 2026) is a real, substantive policy — covers
  account creation, a concrete data-collection table, and a contact section
  (`support@awakenfitness.app`), not a placeholder stub.
- Would be hosted at `https://codestorm-hub.github.io/awaken_v1/privacy-policy.html` if GitHub
  Pages is enabled for that repo — **verify Pages is actually turned on** (Settings → Pages) and
  that the URL resolves before pasting it into Play Console's "Privacy policy" field; Google
  fetches and checks that link.
- Duplicate copies (`PRIVACY_POLICY.md`, `docs/PRIVACY_POLICY.md`) exist — harmless, but make sure
  they don't drift out of sync with the HTML version over time.

### CI/CD
- `.github/workflows/ci.yaml` runs analyze/test/build; `build_ios.yml` builds iOS (manual trigger).
- **No Play Store publish automation** (no fastlane, no upload-google-play action) — you'll be
  uploading the `.aab` by hand through Play Console the first time, which is normal for a first
  release.

---

## 3. Google Play Console steps (2026 rules, personal account)

1. **Closed testing requirement — the real timeline driver.** Personal developer accounts created
   after Nov 13, 2023 (yours) must run a closed test with **≥12 opted-in testers for a continuous
   14 days** before Google will let you request Production access. Start this the moment you have
   a working release build — it's the long pole, not the code.
   [Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
2. **Target API level**: you're already on API 36, clear of both the existing-app deadline
   (API 35 by Aug 31, 2026) and the new-app requirement (API 36). Nothing to do here.
   [Android target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
3. **Store listing assets needed**: app title, short/full description, 512×512 hi-res icon,
   feature graphic (1024×500), at least 2 phone screenshots, content rating questionnaire, target
   audience/age declaration, ads declaration (say "no ads" if none), and the privacy policy URL
   from §2.
4. **Data safety form** (App content → Data safety): declare collection of account
   email/name/profile photo (Google Sign-In), location (for run tracking — "used for app
   functionality," not shared with third parties beyond your Supabase backend), camera (processed
   on-device for pose detection, not stored/transmitted as images — confirm this is actually true
   in code, since how you answer here is a policy commitment). Must match what's actually in the
   privacy policy.
5. **Content rating questionnaire**: fitness/gamification app with camera + location, no violence
   /gambling — should land in the lowest rating tiers, but answer honestly (mentions of a
   leaderboard/squad social feature may trigger a "Users interact" disclosure).
6. **App signing**: let Play Console generate/manage the app signing key from your uploaded
   `upload-keystore.jks` on first upload (Play App Signing) — recommended default, protects you if
   the upload key is ever compromised.
7. **Reviewer access**: since the app requires account creation/anonymous sign-in to use fully,
   provide a test account or note that anonymous sign-in is available, so the reviewer isn't
   blocked at login.

Sources: [Play Console Help — testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), [Target API level requirements](https://developer.android.com/google/play/requirements/target-sdk), [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)

---

## 4. Supabase database review (`awaken-dev`, project `qxxkydisyqnodskmymla`)

- **RLS is enabled on every public table** (`runs`, `territories`, `user_stats`, `bounty_zones`,
  `territory_captures`, `squads`, `active_runs`, `profiles`, `squad_reports`, `alarms`, `sessions`)
  — good baseline.
- **Live data already exists**: 51 `profiles`, 28 `alarms`, 14 `sessions`, 7 `runs`, 6
  `territory_captures`, 5 `squads`/`user_stats` rows. This is a **shared dev project used by both
  `dev` and `prod` flavors** (per your CLAUDE.md decision) — before real users install the
  Play Store build, confirm you're comfortable with production traffic landing in the same
  project as your own test data, since there's no separate prod database.
- **Security advisor warnings** (all `WARN`, none `ERROR`):
  - "Anonymous Access Policies" flagged on every table with an `_own` RLS policy — this is
    **expected and correct** for this app (anonymous sessions are first-class users per your
    design), not a real finding. No action needed.
  - **Leaked Password Protection is disabled** (HaveIBeenPwned check) — this is a genuine,
    zero-cost fix: enable it in Supabase Dashboard → Authentication → Policies. Recommended before
    public launch since real users will be creating passworded accounts (via the anonymous→real
    upgrade flow).
- **Performance advisor**: only `INFO`-level "unused index" notices (e.g. `idx_profiles_squad_id`,
  `idx_runs_user_id`) — expected on a low-volume dev project, not worth acting on pre-launch.
- No `ERROR`-level findings from either advisor.

---

## 5. Recommended action list before submitting

**Must do:**
1. Run a **real signed release build** and smoke-test it on a device: `flutter build appbundle --release --flavor prod -t lib/main_prod.dart`, install the resulting artifact, and exercise alarm-ring, camera verification, and run-tracking flows — the proguard rules just changed and haven't been verified against a real R8 pass yet.
2. Verify GitHub Pages is live and the privacy policy URL resolves.
3. Enable leaked-password protection in Supabase Auth settings.
4. Back up the upload keystore + password outside the repo.
5. Start the 12-tester/14-day closed test track immediately — it gates everything else.

**Should do:**
6. Delete unused stock `ic_launcher.png` files from `mipmap-*dpi/`.
7. Confirm Firebase API key restrictions are set in Google Cloud Console.
8. Decide whether `awaken-dev` should keep serving production traffic, or whether you want a
   separate prod Supabase project before real users' data starts flowing in (currently a
   deliberate choice per your ADRs — just flagging it as a decision point now that release is
   imminent, not a defect).

**Nice to have:**
9. Reconcile the three privacy-policy copies (`docs/privacy-policy.html`, `PRIVACY_POLICY.md`,
   `docs/PRIVACY_POLICY.md`) so future edits don't drift.
10. Add a `CHANGELOG.md` — not required by Play, but useful once you're shipping updates.
