# Implementation Plan - Google Play Compliance Audit Report

**Date:** August 2, 2026  
**Target Application:** Awaken (`com.awaken.awaken` / `com.awaken.awaken.dev`)  
**Auditor & Lead Engineer:** AI Android/Flutter Specialist  

---

## 1. Overview & Objective

This implementation plan provides a safe, step-by-step remediation guide to fix all compliance blockers, high-risk permission issues, and configuration gaps identified in the **Google Play Compliance Audit Report (August 2, 2026)**.

### Strict Constraints Applied
1. **Zero Breaking Changes:** Core application logic, UI/UX layouts, and feature workflows remain untouched.
2. **Backward Compatibility:** Preserves runtime stability on all supported Android OS versions (Android 8.0+ / API 26+).
3. **Isolation:** Policy compliance changes are strictly isolated to build configurations, manifest declarations, privacy utility guards, and release settings.
4. **Verification:** Requires explicit verification commands (`flutter analyze`, `flutter build aab --release --flavor prod`, `flutter build apk --release --flavor prod`) after execution.

---

## 2. Actionable Remediation Steps

### Step 1: Manifest & Environment Asset Fixes (Core Policy & Build Blocker Resolution)

#### A. Production Android Manifest Hardening
* **File:** [android/app/src/main/AndroidManifest.xml](file:///e:/workspace/awaken_v1/android/app/src/main/AndroidManifest.xml)
* **Changes:**
  1. Add `<uses-permission android:name="android.permission.INTERNET" />` to ensure release builds retain network access for Supabase, MapLibre, and Sentry.
  2. Remove `<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />` to pass Google Play Store automated high-risk permission policy scans.
  3. Modify `<uses-feature android:name="android.hardware.camera" android:required="true" />` to `android:required="false"` to prevent restricting app downloads on devices lacking a rear camera.

#### B. Git Asset Tracking Guard
* **File:** [.gitignore](file:///e:/workspace/awaken_v1/.gitignore)
* **Changes:**
  1. Add `!.env.client` exception under the secrets section so the client-side configuration asset is tracked in version control for automated CI/CD builds.

---

## 3. Google Play Console Policy Submission Checklist

Before submitting the app to Google Play Console (Closed Testing, Open Testing, or Production), complete the following declaration forms in Play Console:

### 📋 1. Exact Alarm Permission Declaration Form (`USE_EXACT_ALARM`)
* **Category:** Core Functionality Exemption
* **Declared Use Case:** Alarm Clock / Wake-Up Application
* **Justification Text:** "Awaken is an alarm clock application that requires precise, exact-time alarm ringing to wake users up and initiate exercise verification routines. Standard inexact alarms cannot guarantee timely wake-up notifications."

### 📋 2. Full Screen Intent Declaration Form (`USE_FULL_SCREEN_INTENT`)
* **Category:** High-Priority User Alert
* **Declared Use Case:** Alarm Ringing Screen
* **Justification Text:** "When an active alarm triggers while the device screen is locked or off, Awaken launches a full-screen intent to display the alarm dismissal and camera exercise verification interface directly to the user."

### 📋 3. Foreground Service Declaration Form (`FOREGROUND_SERVICE_LOCATION`)
* **Category:** Location & Run Tracking
* **Declared Use Case:** Active Outdoor Workout & Territory Mapping
* **Justification Text:** "Awaken uses a foreground service with a persistent notification while an outdoor run tracking session is active to calculate run metrics and record territory polygons even when the app is minimized or the screen is off."

### 📋 4. Data Safety Questionnaire & Advertising ID Declaration
* **Data Types Collected:**
  - **Location (Precise Location):** Optional for outdoor run tracking and territory capture. Not shared.
  - **Personal Info (Email & Name):** Optional for account creation and sync via Supabase. Not shared.
  - **Diagnostics (Crash logs & Performance):** Required for app stability via Sentry.
  - **Photos & Videos / Camera:** Select **No** to collection (camera feed is evaluated in RAM on-device for ML Kit pose detection and never saved or transmitted off-device).
* **Advertising ID (`AD_ID`):** Select **No** (The app does not use Advertising ID or third-party ad networks).

---

## 4. Verification & Validation Protocol

After completing the code modifications, execute the following commands to confirm release readiness:

### 1. Static Analysis Check
```powershell
flutter analyze
```
*Expected Result:* `No issues found!`

### 2. Production App Bundle Compilation Test
```powershell
flutter build aab --release --flavor prod
```
*Expected Result:* `Built build\app\outputs\bundle\prodRelease\app-prod-release.aab`

### 3. Production APK Compilation Test
```powershell
flutter build apk --release --flavor prod
```
*Expected Result:* `Built build\app\outputs\apk\prodRelease\app-prod-release.apk`

### 4. Android Manifest Inspection
Inspect the merged release manifest using Android Studio or `aapt`:
- Confirm `android.permission.INTERNET` is present.
- Confirm `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is absent.
- Confirm `android.hardware.camera` has `android:required="false"`.
