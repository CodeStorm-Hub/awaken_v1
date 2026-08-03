# Google Play Store Publishing Guide & Implementation Plan

This document outlines the end-to-end process required to publish the **Awaken** Flutter app to the Google Play Store using a personal developer account as of August 2026. 

It is divided into two phases:
1. **Phase 1: Local Codebase Compliance Fixes** - Resolving issues found in the project audit.
2. **Phase 2: Play Store Console Requirements** - Steps to upload, test, and publish.

## User Review Required

> [!IMPORTANT]
> Please review this plan carefully. Once approved, I will implement the local codebase changes listed in Phase 1. You will then need to handle the manual Play Console steps in Phase 2. 

## Phase 1: Local Codebase Compliance Fixes (Proposed Changes)

Based on the audit of your workspace, the following changes are mandatory to pass Google Play compliance:

### Android Manifest Fixes

#### [MODIFY] AndroidManifest.xml (file:///j:/GitHub/flutter_projects/awaken/android/app/src/main/AndroidManifest.xml)
- **Add INTERNET Permission:** Production builds strip the debug manifest. We must add `<uses-permission android:name="android.permission.INTERNET" />` to the main manifest to ensure the release app can connect to Supabase, MapLibre, and Sentry.
- **Remove Battery Exemptions:** Google Play strictly forbids `<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />` for alarm apps. We must remove this to prevent automated store rejection.
- **Loosen Camera Requirements:** Change `<uses-feature android:name="android.hardware.camera" android:required="true" />` to `android:required="false"` so the app can be installed on devices without rear cameras (the app already does runtime checks).

### Build Configurations

#### [MODIFY] build.gradle.kts (file:///j:/GitHub/flutter_projects/awaken/android/app/build.gradle.kts)
- **Target SDK 36:** Google requires API 36 for all new apps by August 31, 2026. Update `targetSdk = flutter.targetSdkVersion` to `targetSdk = 36`.

#### [MODIFY] pubspec.yaml (file:///j:/GitHub/flutter_projects/awaken/pubspec.yaml)
- Ensure the `flutter_launcher_icons` package is configured to replace default flutter icons with your actual app icon. *(If not present, I will add it and generate the icons).*
- We will verify the `version` string (e.g., `0.1.0+1`) increments with every new Play Store release.

#### [MODIFY] .gitignore (file:///j:/GitHub/flutter_projects/awaken/.gitignore)
- Add `!.env.client` exception so the client environment variables are tracked during CI/CD or automated app bundling.

---

## Phase 2: Google Play Console Publishing Guide (Manual Steps)

Once Phase 1 is complete and we generate the `.aab` (Android App Bundle), you must follow these steps in your Google Play Developer Console to launch your Beta.

### 1. Account Setup & Verification
- **Identity Verification:** Pay the $25 fee (if new) and provide a government-issued photo ID and proof of address matching your Google Payments profile.

### 2. App Signing & Build Upload
- Generate an upload keystore (`upload-keystore.jks`) locally. (I can help you do this locally after Phase 1).
- Create a `key.properties` file in `android/` with your keystore credentials.
- Build the signed App Bundle using `flutter build appbundle --release --flavor prod`.

### 3. Store Listing & Mandatory Declarations
Before Google allows you to start a Beta test, you must prepare:
- **Store Listing Assets:** App Title, Short Description (80 chars), Full Description, 512x512 High-Res Icon, 1024x500 Feature Graphic, and 2-3 Screenshots of Awaken.
- **Privacy Policy URL:** A publicly accessible URL detailing data handling.
- **Mandatory Permissions Declarations:**
  - **Exact Alarm Declaration:** Justify why you need `USE_EXACT_ALARM` (e.g., "Awaken is an alarm clock app needing precise wake-up times").
  - **Full Screen Intent Declaration:** Explain that `USE_FULL_SCREEN_INTENT` is used to wake users with the alarm screen.
  - **Foreground Service Declaration:** Detail why `FOREGROUND_SERVICE_LOCATION` is needed for outdoor run tracking.
- **Data Safety Form:** Declare location data (not shared), crash logs (Sentry), and assert that the camera is used strictly on-device.

### 4. Beta Release (Closed Testing) Phase
> [!WARNING]
> For personal accounts, you **CANNOT** go straight to Open Testing or Production. You must pass a mandatory Closed Testing phase first.
- **Create the Release:** Go to **Testing > Closed testing**. Create a new release, upload your `.aab`, and save.
- **Send for Review:** Send the app for Google Review. **Wait 1-7 days** for approval.
- **Manage Testers:** Once approved, an opt-in link is generated. You must add at least **12 testers** (Google lowered this from 20) via their emails or a Google Group, and share the opt-in link with them.
- **The 14-Day Rule:** The 12+ testers must opt-in, install the app, and open it occasionally over **14 consecutive days**. If the active tester count drops below 12, the clock resets. (Aim for 15-20 testers).
- **Apply for Production:** After 14 continuous days, the "Apply for production" button unlocks. You will fill out a questionnaire detailing tester feedback.

### 5. Open Testing & Production
- Only after Google approves your Production application can you move your release to the **Open Testing (Public Beta)** track or push it to the live **Production** track.

## Verification Plan

### Automated Tests
- `flutter analyze` to ensure no dart warnings are introduced.
- `flutter build aab --release --flavor prod` to verify the App Bundle successfully compiles with the new settings.

### Manual Verification
- Review the `AndroidManifest.xml` visually to confirm the correct permissions are set.
