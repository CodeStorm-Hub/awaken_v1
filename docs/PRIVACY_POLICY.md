# Privacy Policy for Awaken

**Effective Date:** August 1, 2026  
**Last Updated:** August 1, 2026  

---

## 1. Introduction

Welcome to **Awaken** ("we," "our," or "us"). Awaken is a gamified alarm and fitness application that helps users build consistent morning and exercise habits through camera-verified exercise alarm dismissals and GPS-based outdoor territory capture ("Awaken App").

This Privacy Policy explains how we collect, use, store, share, and protect your information when you download, access, or use the Awaken mobile application on Android (Google Play Store) and iOS (Apple App Store).

By installing or using Awaken, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with the terms of this Privacy Policy, please do not use the application.

---

## 2. Information We Collect

We collect information to provide, maintain, and improve our services. The types of information we collect include:

### A. Location Information (Precise & Background Location)
* **What We Collect:** Precise GPS coordinates (latitude, longitude, altitude, speed, bearing) collected during outdoor run tracking sessions.
* **Background Location:** If enabled, location data is collected in the background while a run tracking session is active (even when the app is closed or not actively displayed) to calculate run metrics, detect closed geographic loops, and map conquered territories.
* **How It Is Collected:** Via device GPS location services (`geolocator`, `flutter_foreground_task`).

### B. Camera & Motion Verification Data (Processed On-Device Only)
* **What We Collect:** Live camera stream feed and body pose landmark points (joints, hips, knees, shoulders, arms).
* **On-Device Only Processing:** Camera imagery and pose detection frames are processed **strictly on-device in real-time memory** using Google ML Kit (`google_mlkit_pose_detection`).
* **Zero Video/Photo Storage:** **No camera footage, photos, or video recordings are ever recorded, saved to disk, or transmitted to our servers or any third-party servers.** The camera feed is evaluated instantaneously to count exercise reps (e.g., squats or push-ups) and turned off immediately after verification.

### C. Account & Authentication Data
* **Account Creation:** When you register an account, we collect your email address, display name, and unique User ID (via Supabase Auth or Google Sign-In).
* **Guest / Anonymous Accounts:** If you choose to use Awaken as a guest, a temporary anonymous ID is generated on your device. You can link your guest account to a permanent email or Google Sign-In account later to sync data across devices.

### D. Alarm & Fitness Usage Data
* **Alarm Settings:** Alarm times, repetition schedules, selected verification exercises, and wake-up performance history.
* **Territory & Run Data:** Polygons of captured territory, run routes, total distance, run duration, average speed, and squad leaderboard standings.

### E. Diagnostic & Performance Data
* **Crash Reports & Diagnostics:** We collect crash reports, device performance metrics, OS version, device model, and error stack traces via Sentry (`sentry_flutter`) to diagnose technical glitches and improve app stability.

---

## 3. How We Use Your Information

We use the collected data for the following legitimate business and service purposes:

1. **Core App Functionality:**
   - Scheduling and ringing alarms reliably at set times.
   - Verifying exercise completion via camera pose detection to dismiss active alarms.
   - Tracking runs, smoothing location data (Kalman filtering), and mapping captured territories.
2. **Account Management & Data Sync:**
   - Authenticating your identity and synchronizing your alarms, runs, and territory statistics across your devices via Supabase.
3. **Community & Leaderboards (Squads):**
   - Displaying public territory polygons on shared maps and showing exercise/territory stats on squad leaderboards.
4. **App Improvement & Security:**
   - Identifying crashes, performance bottlenecks, and software bugs.
   - Securing backend databases using Row-Level Security (RLS) policies.

---

## 4. On-Device Storage & Offline-First Architecture

Awaken is designed with an **offline-first architecture**:
* **Local Database:** Your alarms, run history, and territory details are stored locally on your device in an encrypted SQLite database using Drift (`drift`).
* **Data Synchronization:** When internet connectivity is available, changes in the local outbox are securely synchronized with our cloud backend (Supabase).

---

## 5. Third-Party Services & Data Processors

We work with trusted service providers to deliver app features and infrastructure. These third parties process data on our behalf under strict confidentiality agreements:

| Service Provider | Purpose | Data Processed / Shared | Privacy Policy Link |
| :--- | :--- | :--- | :--- |
| **Supabase** | Backend Database, Auth & Storage | Email, User ID, Sync Data (Alarms, Runs, Territories) | [Supabase Privacy Policy](https://supabase.com/privacy) |
| **Google Sign-In** | OAuth Authentication | Google Account Email, Name, Profile Picture | [Google Privacy Policy](https://policies.google.com/privacy) |
| **Google ML Kit** | On-Device Pose Detection | Live Camera Frames (Processed locally in RAM only) | [Google ML Kit Terms](https://developers.google.com/ml-kit/terms) |
| **MapLibre / OpenFreeMap** | Map Vector Tile Rendering | Anonymized tile request coordinates | [MapLibre Privacy](https://maplibre.org/) |
| **Sentry** | Crash Reporting & Performance | Device Model, OS Version, Crash Traces | [Sentry Privacy Policy](https://sentry.io/privacy/) |

---

## 6. Permissions Requested & Justification

Awaken requires specific system permissions to function properly. You can grant or revoke these permissions at any time through your device settings:

* **Location (Foreground & Background):** Required to map outdoor run routes and capture territory polygons on the map during active run sessions.
* **Camera:** Required during alarm ringing to verify exercise completion via on-device pose detection.
* **Notifications:** Required to display active alarm alerts, full-screen wake-up intents, and run tracking notifications.
* **Alarms & Reminders (Exact Alarm / `USE_EXACT_ALARM`):** Required on Android to trigger precise wake-up alarms at exact scheduled times.
* **Foreground Service (`FOREGROUND_SERVICE`):** Required to prevent OS background suspension while ringing alarms or tracking an active outdoor run.

---

## 7. Data Sharing and Disclosure

We **do not sell, rent, or trade** your personal information or location history to advertisers, data brokers, or commercial third parties.

We may disclose information only under the following limited circumstances:
1. **Public Territory Features:** Territory polygons and display names created during runs are visible on shared maps and squad leaderboards.
2. **Legal Compliance:** If required by law, court order, or subpoena, or to protect the safety, rights, or property of Awaken, our users, or the public.
3. **Business Transfers:** In the event of a merger, acquisition, or asset sale, user data may be transferred as a business asset with notice provided.

---

## 8. Data Security, Retention, and Account Deletion

### A. Data Security
We implement industry-standard technical and organizational security measures:
* Encryption in transit using HTTPS / TLS 1.3 for all backend communication.
* Strict PostgreSQL Row-Level Security (RLS) rules ensuring users can only read/modify their own personal records.

### B. Retention Policy
We retain your personal data only for as long as your account remains active or as needed to provide app services.

### C. Account & Data Deletion Rights
You have the right to delete your account and all associated personal data at any time.

* **In-App Deletion:** Go to **Profile / Settings → Account → Delete Account** within the Awaken app.
* **Web Request / Manual Deletion:** If you cannot access the app, you can request account deletion by emailing us at **salman.reza.2026@gmail.com** with the subject line "Account Deletion Request".

Upon deletion, all your personal data, run history, and account credentials will be permanently erased from our primary servers within 30 days.

---

## 9. Children's Privacy

Awaken is not intended for use by children under the age of 13 (or 16 in the European Union). We do not knowingly collect personal data from children. If you become aware that a child has provided us with personal information without parental consent, please contact us, and we will take immediate steps to delete such information.

---

## 10. Your Rights (GDPR, CCPA/CPRA, and International Users)

Depending on your location, you may have the following rights regarding your personal data:
* **Access & Portability:** Request a copy of the personal data we hold about you.
* **Correction:** Request correction of inaccurate personal data.
* **Erasure ("Right to be Forgotten"):** Request deletion of your personal data.
* **Withdraw Consent:** Revoke permissions (e.g., location or camera access) at any time in device settings.

To exercise any of these rights, please contact us at **salman.reza.2026@gmail.com**.

---

## 11. Changes to This Privacy Policy

We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date at the top. You are advised to review this Privacy Policy periodically for any changes.

---

## 12. Contact Us

If you have any questions, concerns, or requests regarding this Privacy Policy, please contact us at:

* **Email:** salman.reza.2026@gmail.com
* **Developer/Company Name:** [Your Name or Company Name]
* **Address:** [Your Business Address / Country]

---

# Store Submission Compliance Appendices

---

## Appendix A: Google Play Console — Data Safety Form Guide

Use the exact responses below when completing the **Data Safety** questionnaire in the Google Play Console for **Awaken**:

### 1. Data Collection & Sharing Summary
* **Does your app collect or share any of the required user data types?** -> **Yes**
* **Is all of the user data collected by your app encrypted in transit?** -> **Yes**
* **Do you provide a way for users to request that their data be deleted?** -> **Yes**

### 2. Specific Data Types Collected & Purpose

| Data Category | Data Type | Collected? | Shared? | Required / Optional | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Location** | Precise Location | **Yes** | No | Optional (Required for Run feature) | App Functionality (Run tracking & territory mapping) |
| **Personal Info** | Email address | **Yes** | No | Optional (For account sync) | Account Management, Authentication |
| **Personal Info** | Name / User ID | **Yes** | No | Optional | App Functionality, Account Management |
| **Fitness** | Fitness & Exercise data | **Yes** | No | Optional | App Functionality (Alarm verification & territory metrics) |
| **App Info & Perf** | Crash logs | **Yes** | **Yes** (with Sentry) | Required | Analytics & App Stability |
| **App Info & Perf** | Diagnostics | **Yes** | **Yes** (with Sentry) | Required | Analytics & Performance |
| **Photos & Videos** | Photos / Videos / Camera | **No** (Processed in RAM only) | No | N/A | Camera feed processed in memory on-device; never saved or sent off-device |

---

## Appendix B: Apple App Store Connect — App Privacy Details (Privacy Labels)

Use the responses below when answering the **App Privacy** section in App Store Connect:

### 1. Data Types Collected

* **Precise Location:**
  - **Used for:** App Functionality
  - **Linked to User:** Yes
  - **Tracking Purposes:** No

* **Contact Info (Email Address, Name):**
  - **Used for:** App Functionality, Account Management
  - **Linked to User:** Yes
  - **Tracking Purposes:** No

* **Fitness & Movement Data:**
  - **Used for:** App Functionality
  - **Linked to User:** Yes
  - **Tracking Purposes:** No

* **Diagnostics (Crash Data, Performance Data):**
  - **Used for:** App Functionality, Analytics
  - **Linked to User:** No (Anonymized diagnostic sessions)
  - **Tracking Purposes:** No

* **User Identifiers (User ID):**
  - **Used for:** App Functionality
  - **Linked to User:** Yes
  - **Tracking Purposes:** No

### 2. Camera Data Note for App Store
When Apple asks if the app collects Camera data:
* Answer **"No"** to collection if camera frame data is not stored or transmitted off-device (processed solely in memory for real-time ML pose detection).
