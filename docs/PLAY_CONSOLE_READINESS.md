# Google Play Console — Production Readiness Checklist

Written 2026-08-04. This doc is specifically about **getting this build onto Google Play**, as
distinct from `docs/SESSION_HARDENING_STATUS.md` (functional/security bugs in the app itself,
already extensively worked through). Re-check anything marked `[ ]` before your first submission;
items marked `[x]` were verified in this session against actual current source/build output, not
assumed from docs.

---

## 1. Release signing — DONE this session

- [x] Generated a real upload keystore: `android/app/upload-keystore.jks` (RSA 2048, alias
      `awaken_upload`, valid 30 years) + `android/key.properties` (passwords: 28-char random
      alphanumeric, store/key password identical — required for PKCS12 keystores, which is what
      modern `keytool` defaults to).
- [x] Added `android/key.properties`, `*.jks`, `*.keystore` to `.gitignore` — previously **not**
      ignored (only would have mattered once the files existed, which they now do).
- [x] Verified via a real `flutter build appbundle --release --flavor prod -t lib/main_prod.dart`
      that the output `.aab` is signed with this key, not the debug fallback — extracted
      `META-INF/AWAKEN_U.RSA` from the built bundle and confirmed its SHA-256 fingerprint
      (`0A:FC:A0:B2:3E:3F:90:09:0D:58:E5:DF:02:58:BD:AC:96:39:A3:5E:B3:26:F1:F6:DA:86:ED:1C:60:33:E8:80`)
      matches the keystore exactly.
- [x] `flutter analyze` clean, all 140 `flutter test` cases pass, both before and after this
      session's changes.

**Your action required — back up the keystore now, before doing anything else:**
1. Copy `android/app/upload-keystore.jks` **and** `android/key.properties` somewhere durable and
   private (password manager attachment, encrypted drive backup, etc.) — both are gitignored and
   exist only on this machine. If you lose them, you cannot publish an update to this app under
   the same listing without going through Play Console's account-recovery process for a lost
   upload key.
2. When you create the app in Play Console, enroll in **Play App Signing** (Google manages the
   final signing key; this upload key just authenticates you to Google) — this is the default and
   recommended path, and also means a lost upload key is recoverable via Play Console support
   rather than fatal.
3. Do not regenerate this keystore casually — every rebuild must use the same one going forward.

## 2. In-app legal links — DONE this session

- [x] Added a `url_launcher` dependency and two new rows under Profile → Settings ("Privacy
      Policy", "Terms & Conditions") that open the hosted pages — previously there was **no
      in-app link to either document at all**, which Play's policy for apps requesting sensitive
      permissions (location, camera) generally expects, separately from the store-listing privacy
      policy URL field.
- [x] Fixed a factual inaccuracy in `docs/privacy-policy.html`: it claimed background location
      collection ("If enabled, location data is collected in the background...") which doesn't
      match the app's actual behavior — `ACCESS_BACKGROUND_LOCATION` is deliberately never
      requested (CLAUDE.md §"Manifest permissions"). Corrected to describe foreground-only
      collection.
- [x] Created `docs/terms.html` (was previously only a `.md` file, not servable as a clean page)
      from the existing `docs/TERMS_AND_CONDITIONS.md` content, matching `privacy-policy.html`'s
      styling.

**Your action required:**
1. `docs/terms.html` still has **three unfilled legal placeholders** (highlighted in red on the
   page itself): governing-law jurisdiction/city (§14), and developer/company name + business
   address (§16, footer). Fill these in with real values — a Terms page with visible `[Your ...]`
   placeholders is not something to ship.
2. Confirm GitHub Pages is actually enabled and serving `/docs` for this repo (Settings → Pages →
   Source: branch `master`, folder `/docs`) — `AppConstants.privacyPolicyUrl`/`termsAndConditionsUrl`
   in `lib/core/constants/app_constants.dart` now hardcode
   `https://codestorm-hub.github.io/awaken_v1/...`; if Pages isn't enabled or uses a different
   path, those links 404 both in-app and from the Play Store listing's privacy policy field.
3. Commit and push `docs/terms.html` and the `privacy-policy.html` fix so Pages actually serves
   the updated content.

## 3. Data Safety form — drafted this session

- [x] `docs/PLAY_DATA_SAFETY.md` — a data-type-by-data-type mapping (location, camera, personal
      info, fitness data, diagnostics) to fill out Play Console's Data Safety questionnaire,
      derived from actually grepping the codebase for upload/analytics calls (confirmed: no
      analytics SDK, no image/video upload path — camera frames are genuinely on-device only).

**Your action required:** actually fill out the Play Console form using that doc as a reference —
it's a starting draft, and the questionnaire's exact wording/categories can shift between Play
Console versions.

## 4. Known blockers this session could not resolve (need your decision/action)

- [ ] **`main_prod.dart` points at the `awaken-dev` Supabase project.** This is a deliberate,
      already-documented TODO (CLAUDE.md, SESSION_HARDENING_STATUS.md) — decide whether you're
      shipping v1 against the dev project (fine for a small early launch, some teams do this
      intentionally) or need to provision a separate `awaken-prod` Supabase project and repoint
      `.env.client.prod` before submitting.
- [ ] **Play Console account + app listing setup** — not something I can do from here (needs your
      Google Play Developer account, $25 one-time fee if not already paid, and console access).
- [ ] **Store listing assets** — screenshots (phone + optionally tablet), feature graphic
      (1024×500), short/full description, app category, contact email. None of this exists in the
      repo yet; screenshots in particular need a real device/emulator run through each major
      screen.
- [ ] **Content rating questionnaire** (IARC, inside Play Console) — this app has no violence/
      mature content but does collect location and has social/leaderboard features; answer
      honestly, it's a quick form, not a blocker beyond filling it out.
- [ ] **Restricted-permissions declarations** — Play Console has dedicated declaration forms for
      apps requesting `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` (Alarms & Reminders special access)
      and foreground location + `FOREGROUND_SERVICE_LOCATION`. Both are legitimately justified
      here (exact alarm firing, live run tracking) — when Play Console prompts for the
      declaration form during submission, the justification is essentially "the app's core
      function requires it," but you'll need to write the actual justification text and (for
      background-sensitive permissions) may need to submit a short demo video — check what Play
      Console actually asks for at submission time, requirements shift.
- [ ] **First release track** — recommend starting on **Internal testing** (fast, no review) →
      **Closed testing** (some real users, 14-day minimum before eligible for production per
      Play's current new-developer requirements) → **Production**, rather than submitting
      straight to production.
- [ ] **App size** — the current release `.aab` is **120.3MB**. That's on Play's app-bundle size
      limit (`.aab` itself, not per-device delivery — Play's dynamic delivery splits by ABI/
      density/language so actual per-device download is smaller, typically well under Play's
      150MB base-APK-equivalent limit, but worth a real Play Console "app size" check after
      upload rather than assuming). Largest likely contributors: MapLibre native libs, ML Kit
      pose-detection models, multiple ABIs bundled into one `.aab` (normal for App Bundles — Play
      strips to the target device's ABI at install time, this isn't a red flag by itself).

## 5. Already correctly configured — verified, not re-explained here

`compileSdk`/`targetSdk` 36 (current Play requirement), `minSdk` 26, ProGuard/R8 minification +
resource shrinking enabled with a working rule set (verified via a real release build, not just
config presence), adaptive launcher icon, foreground-service manifest declaration + type,
`ACCESS_BACKGROUND_LOCATION` correctly *not* requested, 16KB page-size CI smoke job already in
place. See `docs/SESSION_HARDENING_STATUS.md` for the much larger list of functional/security
fixes already applied across the app's features — that work is a prerequisite for a *good* launch,
this doc is about the submission mechanics specifically.
