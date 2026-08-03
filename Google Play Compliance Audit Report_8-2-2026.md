# Google Play Store Compliance & Technical Audit Report

**Date:** August 2, 2026  
**Target Application:** Awaken (`com.awaken.awaken` / `com.awaken.awaken.dev`)  
**Platform:** Android / Flutter  
**Auditor:** AI Android/Flutter Engineer & Google Play Store Compliance Specialist  

---

## Executive Summary

A comprehensive, deep-scan audit was conducted across the entire Awaken workspace (`android/`, `lib/`, `pubspec.yaml`, `AndroidManifest.xml`, build Gradle scripts, static assets, and environment variables). The app was evaluated against **Google Play Developer Policies**, **Developer Distribution Agreements**, **Target API Level Requirements (Android 14 / API 34+)**, and high-risk permission handling policies.

### Audit Summary Matrix
| Category | Status | Issues Identified |
| :--- | :--- | :--- |
| **Target SDK & Build Config** | ✅ PASSED | `compileSdk 36`, `targetSdk 34+` configured via Flutter DSL |
| **Manifest Permissions** | ❌ RED FLAG | Missing `INTERNET` permission in production manifest; Restricted `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission present |
| **Declarations & Declarative Permissions** | ⚠️ WARNING | `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, and `FOREGROUND_SERVICE_LOCATION` require Play Console forms |
| **Privacy, Data Safety & Tracking** | ✅ PASSED | On-device pose detection (zero camera upload), Sentry data scrubbing active, no Advertising ID (`AD_ID`) needed |
| **In-App Billing & Payments** | ✅ PASSED | No third-party payment gateways; compliant with Google Play Billing Policy |
| **Obfuscation & Performance** | ✅ PASSED | R8 / ProGuard minification & resource shrinking enabled (`isMinifyEnabled true`) |
| **Network Security** | ✅ PASSED | All endpoints use HTTPS; cleartext traffic disabled |

---

## ❌ Non-Compliant Items / Blockers (Red Flags)
*(Critical items that cause immediate Google Play Store rejection or application suspension)*

### 1. Missing `INTERNET` Permission in Production Manifest
* **Issue:** `<uses-permission android:name="android.permission.INTERNET"/>` is completely absent from the main production manifest.
* **File/Location:** [android/app/src/main/AndroidManifest.xml](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml)
* **Play Store Policy Violated:** Core App Technical Functionality & Google Play Developer Distribution Agreement (DDA).
* **Why it Fails:** The `INTERNET` permission is currently declared only in `src/debug/AndroidManifest.xml` and `src/profile/AndroidManifest.xml`. When building production release binaries (`flutter build aab --release --flavor prod`), Gradle strips debug/profile manifests. In release mode, the app will have zero network capability, causing Supabase authentication, outbox sync, MapLibre tile loading, and Sentry crash reporting to fail catastrophically on end-user devices.

### 2. Restricted High-Risk Permission `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` Declared in Manifest
* **Issue:** Manifest contains `<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>`.
* **File/Location:** [android/app/src/main/AndroidManifest.xml#L18](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml#L18)
* **Play Store Policy Violated:** Google Play Restricted Permissions Policy (Battery Optimization Policy).
* **Why it Fails:** Google Play strictly forbids declaring `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in `AndroidManifest.xml` unless the app qualifies for very narrow exemptions (e.g., VPNs, IoT device managers). Google Play automated submission scanners flag and reject apps declaring this permission directly. Alarm clocks and location tracking apps must rely on standard platform mechanisms (`ForegroundService`, `AlarmManager.setExactAndAllowWhileIdle()`, and optional user guidance to system battery settings via `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` without the manifest permission).

---

## ⚠️ Warnings & Potential Risks (Yellow Flags)
*(Items requiring store listing declarations, submission forms, or build configuration adjustments)*

### 1. `USE_EXACT_ALARM` & `SCHEDULE_EXACT_ALARM` Policy Declaration Required
* **Issue & Impact:** The app declares both exact alarm permissions. On Android 13+ (API 33+), `USE_EXACT_ALARM` is a restricted permission.
* **File/Location:** [android/app/src/main/AndroidManifest.xml#L7-L8](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml#L7-L8)
* **Remediation & Action:** Because Awaken is an alarm clock app, the use of `USE_EXACT_ALARM` is permitted under policy, but the developer **MUST** complete the **Exact Alarm Declaration Form** in the Google Play Console during app submission.

### 2. `USE_FULL_SCREEN_INTENT` Restricted Permission Declaration
* **Issue & Impact:** On Android 14+ (API 34+), `USE_FULL_SCREEN_INTENT` is restricted to high-priority notification use cases (calling & alarm clock apps).
* **File/Location:** [android/app/src/main/AndroidManifest.xml#L9](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml#L9)
* **Remediation & Action:** Must complete the **Full Screen Intent Declaration Form** in Google Play Console explaining the full-screen alarm wake-up interface.

### 3. Foreground Service (`location` & `mediaPlayback`) Declarations
* **Issue & Impact:** Android 14+ requires `foregroundServiceType` to be declared in the manifest (declared: `location`) and declared in Play Console.
* **File/Location:** [android/app/src/main/AndroidManifest.xml#L12-L14, L60-L63](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml#L12-L14)
* **Remediation & Action:** Must complete the **Foreground Service Declaration Form** in Google Play Console detailing why location tracking is required during active outdoor runs.

### 4. Rigid Camera Hardware Feature Requirement (`android.hardware.camera`)
* **Issue & Impact:** `<uses-feature android:name="android.hardware.camera" android:required="true" />` prevents installation from Google Play Store on devices without a rear/back camera (tablets, Chromebooks, front-camera-only devices).
* **File/Location:** [android/app/src/main/AndroidManifest.xml#L19](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml#L19)
* **Remediation & Action:** Change `android:required="true"` to `android:required="false"`. The application already performs runtime checks for camera availability before initiating ML Kit pose detection.

### 5. `.env.client` Asset & `.gitignore` Un-tracking Risk
* **Issue & Impact:** `.gitignore` ignores `.env.*`, which can prevent `.env.client` from being checked into git or preserved in CI/CD build environments.
* **File/Location:** [pubspec.yaml#L95](file:///e:/workspace/awaken_v1/pubspec.yaml#L95) and [.gitignore#L52](file:///e:/workspace/awaken_v1/.gitignore#L52)
* **Remediation & Action:** Add `!.env.client` to `.gitignore` so the bundled client environment asset is guaranteed to exist during automated build steps.

---

## ✅ Passed Checks

1. **Target SDK & Build Requirements:**
   - `compileSdk` is set to `36`.
   - `targetSdk` is set to `flutter.targetSdkVersion` (API 34+ / Android 14+ compliant).
   - `versionCode` (1) and `versionName` ("0.1.0") are properly synchronized from `pubspec.yaml`.
   - Android App Bundle (`.aab`) compilation with product flavors (`dev` & `prod`) is properly configured.

2. **Obfuscation & Code Security:**
   - ProGuard / R8 minification & resource shrinking are explicitly enabled in release builds (`isMinifyEnabled = true`, `isShrinkResources = true`).
   - Custom rules in [proguard-rules.pro](file:///e:/workspace/awaken_v1/android/app/proguard-rules.pro) keep ML Kit, MapLibre JNI, and Gson serialization bindings intact.

3. **Privacy, Data Safety & Sensitive Data Handling:**
   - **Camera & Pose Detection:** Camera frames are evaluated strictly in RAM on-device using Google ML Kit (`google_mlkit_pose_detection`). Zero photos or videos are stored or transmitted off-device.
   - **Diagnostic Data Scrubbing:** `_scrubSensitiveKeys` in [lib/main_common.dart](file:///e:/workspace/awaken_v1/lib/main_common.dart) redacts GPS coordinates, route points, and frame data prior to sending events to Sentry.
   - **Advertising ID (`AD_ID`):** No ad networks or ad trackers (AdMob, Firebase Ads) are included in `pubspec.yaml`. `AD_ID` permission is not declared.

4. **In-App Billing & Payments Compliance:**
   - The application does not process digital sales or subscriptions through third-party gateways (Stripe/PayPal), fully adhering to Google Play Billing policies.

5. **Network Security:**
   - All network endpoints (Supabase, Sentry, OpenFreeMap) enforce HTTPS protocols. Cleartext HTTP traffic is disabled.

6. **Privacy Policy Documentation:**
   - A comprehensive [PRIVACY_POLICY.md](file:///e:/workspace/awaken_v1/PRIVACY_POLICY.md) document exists, complete with explicit Play Console Data Safety questionnaire mappings.

---

## Conclusion & Next Steps

The Awaken application has a solid architectural foundation, strong privacy practices, and proper code obfuscation setup. Resolving the two **Red Flag** items in `AndroidManifest.xml` and configuring the required Play Console declaration forms will place the application in **100% compliance with Google Play Store Policies**.

See [Implementation Plan - Google Play Compliance Audit Report_8-2-2026.md](file:///e:/workspace/awaken_v1/Implementation%20Plan%20-%20Google%20Play%20Compliance%20Audit%20Report_8-2-2026.md) for the exact step-by-step remediation plan.
