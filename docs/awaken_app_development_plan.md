# **Technical Blueprint and Software Requirements Specification for the "Awaken" Android Application**

The "Awaken" application represents a sophisticated convergence of fitness tracking, gamification, and edge-based machine learning. By compelling users to perform verified physical exercises to dismiss alarms, and gamifying outdoor activity through map-based territory capture, the system demands a highly resilient, offline-capable, and sensor-heavy architecture. This document provides an exhaustive Software Requirements Specification (SRS), architectural blueprint, and step-by-step implementation guide for building Awaken from scratch using the Flutter framework and a Supabase backend.

## **Architectural Refinements and Strategic Enhancements**

Based on a comprehensive review of modern Android development standards, geographic information systems (GIS), and offline-first mobile architectures, several critical refinements to the original project plan are necessary to ensure production readiness. The architecture must transition from a traditional network-dependent model to a robust offline-first paradigm. Relying on standard network-first calls with local fallbacks leads to inevitable data loss during spotty connections, such as when a user runs through a tunnel or experiences network handoff delays1. The application must implement a true offline-first approach using a local SQLite database, managed via the Drift Object-Relational Mapping (ORM) library, combined with a transactional "Outbox" pattern. All data mutations must occur on the local database instantly, providing immediate UI feedback, while a background synchronization engine queues and pushes these operations to the Supabase backend when connectivity is restored2.  
Furthermore, strict compliance with the Android 14 (API 34\) permission model is required. The Android operating system now strictly limits the USE\_FULL\_SCREEN\_INTENT permission to dialer and alarm applications to prevent credential phishing and ad spam4. Awaken must be explicitly categorized as an alarm application on the Google Play Console. The codebase must implement runtime checks using the NotificationManager.canUseFullScreenIntent() API, actively redirecting users to the system settings page via ACTION\_MANAGE\_APP\_USE\_FULL\_SCREEN\_INTENT if the permission is revoked5. Without this refinement, the core functionality of waking the device and bypassing the lock screen will silently fail on modern Android devices.  
Precision in geographic tracking represents another area requiring architectural enhancement. Raw Global Positioning System (GPS) data is inherently noisy, subject to atmospheric interference and multipath errors, which results in jittery map paths and inaccurate polygon closures. To mitigate this, the application must process raw location data through a 4D Extended Kalman Filter. This algorithm models latitude, longitude, speed, and heading to maintain accurate trajectory predictions, essentially performing dead-reckoning when satellite locks are temporarily lost6. Coupled with this precision, stringent anti-cheat mechanisms must be enforced. To prevent users from spoofing locations or driving to capture territory, the system must utilize the isMocked property on geolocation payloads to detect fake GPS signals9. Additionally, velocity checks must be enforced via PostGIS triggers on the backend to invalidate runs exceeding human sprinting speeds12.

## **Software Requirements Specification (SRS)**

The functional and operational parameters of the Awaken application are defined through rigorous user stories, functional requirements, and non-functional requirements. These elements dictate the expected behavior of the system across its primary domains: alarm management, biometric verification, geospatial tracking, and offline synchronization.

### **User Stories and System Flows**

The application's value proposition is driven by specific user interactions, spanning from initial onboarding to complex, multi-user competitive mechanics. The table below outlines the core user stories that dictate the architectural requirements.

| Identifier | User Story Description | Architectural Implication |
| :---- | :---- | :---- |
| **US-01** | As a user, I want to use the application immediately offline as a guest, and have my data migrate automatically to the cloud upon account creation. | Requires an offline-first SQLite database and an adoption routine to re-key local data to a remote auth.uid() upon OAuth login1. |
| **US-02** | As a user, my scheduled alarm must wake the device screen, bypass the lock screen, and remain non-dismissible until physical proof of exercise is verified. | Necessitates the integration of Android AlarmManager, WakeLocks, and Full-Screen Intents natively in Kotlin12. |
| **US-03** | As a user, I want real-time visual feedback on my exercise form (e.g., squats, push-ups) via an overlay skeleton to ensure accurate repetition counting. | Requires the Google ML Kit Pose Detection API running in STREAM\_MODE with a 33-point skeletal extraction pipeline15. |
| **US-04** | As a user, if I ignore an alarm for more than two hours, the required repetitions must automatically multiply as a "Wake-Up Tax." | Requires local timestamp tracking for the last successful alarm dismissal to apply multiplier logic to the next alarm session12. |
| **US-05** | As a user, tracking an outdoor run that forms a closed geographic loop must claim the enclosed physical area on a global map. | Requires background location tracking, geometric processing (ST\_MakePolygon), and closure validation12. |
| **US-06** | As a user, capturing a territory that overlaps a rival's territory must deduct the overlapping area from the rival and add it to my domain. | Necessitates PostGIS integration utilizing ST\_Difference to calculate and subtract overlapping polygons dynamically13. |
| **US-07** | As a user, joining a "Squad" must allow the streaming of live workout progress to friends to maintain motivation. | Requires WebSocket integration via Supabase Realtime to broadcast local mutation states to active squad members12. |

The user flows derived from these stories represent the operational sequences the application must execute. The onboarding and permission flow is particularly critical, as the application requires deep system access. Upon launch, the user is prompted with an educational screen explaining the necessity of exact alarms, full-screen intents, camera access, and "always-on" location permissions. The system sequentially requests POST\_NOTIFICATIONS, SCHEDULE\_EXACT\_ALARM, USE\_FULL\_SCREEN\_INTENT, and ACCESS\_BACKGROUND\_LOCATION4.  
The alarm trigger flow dictates that when the OS fires the registered exact alarm, a native background receiver acquires a WakeLock and launches the MainActivity using FLAG\_SHOW\_WHEN\_LOCKED and FLAG\_TURN\_SCREEN\_ON14. The Flutter UI mounts, bypassing the lock screen, and initiates the camera feed. During the exercise verification flow, the camera streams frames to ML Kit, calculating joint angles to track the transition between "Up" and "Down" states. Upon reaching the target rep count, the audio terminates, and the session is logged to the local Drift database, triggering the background sync engine3. Finally, the territory run flow relies on a foreground service to maintain GPS tracking while the app is suspended. The coordinates are smoothed via a Kalman filter, and upon loop closure, the polygon geometry is generated and pushed to the Supabase PostGIS backend for ownership assignment6.

### **Functional Requirements**

The functional requirements define the precise capabilities the software must possess to fulfill the user stories.

| Requirement ID | Feature Category | Detailed Description |
| :---- | :---- | :---- |
| **FR-01** | Alarm Persistence | The system must utilize Android's AlarmManager for precise scheduling and implement a BroadcastReceiver listening for ACTION\_BOOT\_COMPLETED to restore alarms upon device restart22. |
| **FR-02** | Full-Screen Execution | Alarms must wake the device, present a non-dismissible UI over the lock screen using FLAG\_SHOW\_WHEN\_LOCKED, and play audio at maximum volume until biometric verification is complete14. |
| **FR-03** | Biometric Pipeline | The system must process live camera frames (minimum 15 FPS), extract 33 skeletal landmarks, and compute 3D coordinate angles to classify exercises completely offline12. |
| **FR-04** | Background Tracking | The application must execute a foreground service with an ongoing notification to sample GPS coordinates continuously, actively discarding any coordinates flagged by isMocked10. |
| **FR-05** | Geometric Engine | The Supabase backend must process LineString paths into Polygon types, validate closure via ST\_IsClosed, resolve self-intersections, and calculate turf overlap using ST\_Difference17. |
| **FR-06** | Transactional Sync | All user-generated data must be written to a local SQLite database first. An outbox worker must sequentially flush mutations to the Supabase API, utilizing exponential backoff for network failures1. |

### **Non-Functional Requirements**

The non-functional requirements dictate the system's operational constraints, ensuring stability, performance, and security.

| Requirement ID | Constraint Category | Detailed Description |
| :---- | :---- | :---- |
| **NFR-01** | Thermal Management | Continuous ML Kit and GPS processing exert heavy thermal loads. The system must throttle frame processing or utilize ML Kit in STREAM\_MODE to balance battery life and CPU heat12. |
| **NFR-02** | Architecture | The codebase must rigidly adhere to Feature-First Clean Architecture, ensuring UI, Domain, and Data layers are encapsulated within feature modules to support scalability29. |
| **NFR-03** | Security | All backend tables must enforce Row-Level Security (RLS) ensuring strict auth.uid() scoping. Sensitive local data must be encrypted, and anti-tamper constraints must remain active1. |
| **NFR-04** | Resiliency | The synchronization engine must never drop data. It must use UUIDv4 identifiers generated on the client to prevent ID collisions and ensure idempotency during API retries1. |

## **System Architecture and Data Model**

The application's architecture is predicated on a distributed data model, where the local SQLite database acts as the primary source of truth for the user interface, while the Supabase Postgres instance acts as the authoritative remote replica. This ensures that the application remains fully functional regardless of network availability. The Entity Relationship Diagram (ERD) defines the structure of both the local and remote schemas.

| Entity | Attribute | Data Type | Constraints and Relationships |
| :---- | :---- | :---- | :---- |
| **profiles** | id | UUID | Primary Key, matches Supabase auth.uid()1. |
|  | display\_name | VARCHAR | Unique identifier for social features. |
|  | territory\_color | VARCHAR | Hexadecimal code for map rendering. |
|  | streak\_tier | INTEGER | Evaluates health decay resistance (Bronze, Silver, Gold). |
| **alarms** | id | UUID | Primary Key, client-side generated to prevent collision. |
|  | user\_id | UUID | Foreign Key referencing profiles.id. |
|  | scheduled\_time | TIMESTAMP | Stored in UTC. |
|  | exercise\_mode | VARCHAR | Defines the required biomechanical model (Squat, Pushup). |
|  | required\_reps | INTEGER | The base repetition target. |
|  | penalty\_multiplier | INTEGER | Applies exponential growth to required\_reps if ignored. |
| **sessions** | id | UUID | Primary Key. |
|  | user\_id | UUID | Foreign Key referencing profiles.id. |
|  | alarm\_id | UUID | Foreign Key referencing alarms.id. |
|  | reps\_completed | INTEGER | The actual number of verified repetitions executed. |
|  | completed\_at | TIMESTAMP | The exact timestamp of session termination. |
| **territories** | id | UUID | Primary Key. |
|  | user\_id | UUID | Foreign Key referencing profiles.id. |
|  | geom | GEOMETRY | PostGIS Polygon utilizing SRID 432613. |
|  | area\_sqm | FLOAT | Computed dynamically via the ST\_Area function. |
|  | health | INTEGER | An index (0-100) determining vulnerability to capture. |
| **runs** | id | UUID | Primary Key. |
|  | user\_id | UUID | Foreign Key referencing profiles.id. |
|  | path | GEOMETRY | PostGIS LineString utilizing SRID 4326\. |
|  | is\_closed\_loop | BOOLEAN | Evaluated by backend GIS functions for validity. |
| **sync\_outbox** | id | UUID | Primary Key, exists exclusively on the client database. |
|  | operation | VARCHAR | Denotes the mutation type (INSERT, UPDATE, DELETE)3. |
|  | payload | JSONB | The serialized entity data pending synchronization. |
|  | attempt\_count | INTEGER | Tracks failures to calculate exponential backoff timing. |

The integration of PostGIS within the Supabase architecture is paramount. When a run is synchronized, Supabase Edge Functions evaluate the path geometry. If the run constitutes a closed loop, the function transforms the LineString into a Polygon. It then queries the database for spatial intersections using ST\_Intersects. If the new polygon overlaps an existing territory owned by another user, the backend calculates the difference using ST\_Difference, updating the geometries of both entities to reflect the new territorial boundaries13.

## **Core Constants, Permissions, and Dependencies**

To interact with the device's hardware, the application requires a strictly defined set of Android permissions. These permissions must be declared in the AndroidManifest.xml and requested at runtime in accordance with modern Android privacy guidelines.

| Permission Constant | Architectural Purpose |
| :---- | :---- |
| POST\_NOTIFICATIONS | Mandatory for Android 13+ to display foreground service notifications and trigger Full-Screen Intents22. |
| SCHEDULE\_EXACT\_ALARM | Permits the application to schedule precise wake-up events via the AlarmManager API12. |
| USE\_FULL\_SCREEN\_INTENT | Grants the capability to bypass the lock screen and display urgent UI elements4. |
| ACCESS\_FINE\_LOCATION | Required for high-precision GPS tracking necessary for accurate territory loop mapping12. |
| ACCESS\_BACKGROUND\_LOCATION | Prevents the operating system from suspending GPS polling when the screen is locked during a run18. |
| FOREGROUND\_SERVICE | Required to host background workers and location trackers securely27. |
| FOREGROUND\_SERVICE\_LOCATION | A specific Android 14 declaration indicating the foreground service relies on location data27. |
| WAKE\_LOCK | Keeps the CPU active to process heavy machine learning frames and emit continuous audio14. |
| RECEIVE\_BOOT\_COMPLETED | Allows the application to reschedule exact alarms transparently when the device is rebooted22. |

The technology stack relies entirely on free, open-source packages suitable for commercial distribution, strictly avoiding dependencies with prohibitive licensing or usage-based pricing models for core features.

| Package Dependency | Version | Strategic Purpose in Architecture |
| :---- | :---- | :---- |
| flutter\_bloc | ^8.1.5 | Provides robust state management, enforcing the separation of concerns required by Clean Architecture12. |
| supabase\_flutter | ^2.0.0 | Serves as the Backend-as-a-Service interface, handling authentication, database operations, and real-time WebSockets36. |
| drift & sqlite3\_flutter\_libs | ^2.26.0 | Provides an advanced, type-safe SQLite ORM essential for the offline-first local storage engine37. |
| offline\_first\_sync\_drift | ^0.1.1 | Implements the Outbox pattern engine, ensuring seamless, conflict-free synchronization between Drift and Supabase37. |
| google\_mlkit\_pose\_detection | ^0.14.0 | Executes on-device, low-latency 33-point skeletal landmark detection without requiring an internet connection39. |
| camera | ^0.10.6 | Captures raw frames and pipes the byte streams directly into the ML Kit image processor40. |
| flutter\_foreground\_task | ^9.2.2 | Guarantees the reliable execution of background location isolates and alarm triggers42. |
| geolocator | ^14.0.3 | Handles fine location sampling and features a critical built-in mock location detection boolean for anti-cheat9. |
| kalman\_dr | ^0.2.0 | Deploys a 4D Extended Kalman Filter to eliminate GPS jitter and predict dead-reckoning vectors7. |
| flutter\_map & latlong2 | ^6.0.0 | Renders OpenStreetMap tiles, entirely bypassing the high API costs associated with Google Maps6. |
| android\_alarm\_manager\_plus | ^3.0.0 | Schedules exact timing intents natively with Android's AlarmManager APIs12. |
| get\_it & injectable | ^7.7.0 | Automates dependency injection, strictly decoupling Repositories from UseCases and ViewModels35. |
| turf | ^0.0.12 | Executes client-side geometric mathematics for fast proximity and boundary evaluations before server submission44. |

## **Comprehensive Step-by-Step Implementation Guide**

Constructing Awaken requires a meticulous approach, beginning with the foundational directory architecture and culminating in the integration of complex geospatial and machine learning algorithms. The following phases dictate the implementation strategy.

### **Phase 1: Project Initialization and Feature-First Architecture**

The foundation of Awaken relies on a strict Feature-First Clean Architecture paradigm. This methodology guarantees that highly complex features—such as ML Vision, Geolocation, and Offline Sync—do not leak state across the application, remaining isolated, testable, and modular29.  
Developers must first initialize the project utilizing the Flutter Command Line Interface, ensuring the organization identifier is set appropriately to match Firebase and Supabase configurations. Once initialized, the lib/ directory must be restructured away from traditional layer-based folders (e.g., grouping all models together) and instead organized by feature.

| Directory Structure | Architectural Responsibility |
| :---- | :---- |
| lib/core/ | Houses global themes, network information, error handling classes, and application-wide constants. |
| lib/features/alarm/ | Contains the Data, Domain, and Presentation layers specifically for alarm scheduling and the ML Kit verification screen. |
| lib/features/territory/ | Encapsulates the logic for background GPS tracking, map rendering, and polygon mathematics. |
| lib/features/squad/ | Manages the social components, WebSocket subscriptions, and leaderboard rendering. |
| lib/sync/ | Isolates the Drift database configuration, schema definitions, and the transactional Outbox logic3. |

Dependency injection must be established immediately using the get\_it and injectable packages. Developers must map specific local Data Sources (interacting with Drift) and remote Data Sources (interacting with Supabase) to abstract Repository interfaces within the Domain layer. The Presentation layer (UI) must exclusively interact with ViewModels (implemented via flutter\_bloc), which in turn invoke specific UseCases from the Domain layer. This strict dependency rule ensures that UI changes never inadvertently break business logic30.

### **Phase 2: Offline-First Synchronization Engine Construction**

Awaken must function flawlessly without an active internet connection, persisting alarm completions and territory runs locally before migrating them to the cloud via the Outbox pattern.  
The implementation begins by defining the Drift SQLite schemas, ensuring every entity table includes updated\_at, deleted\_at, and is\_synced columns. Following the schema definition, the Outbox Repository must be constructed. Whenever a domain mutation occurs—such as a user successfully logging 20 push-ups—the repository must open a SQLite transaction. Within this single transaction, the data is written to the primary sessions table, and an event record (e.g., INSERT, sessions, payload) is simultaneously written to the sync\_outbox table. A client-side UUID must be generated for the outbox event to guarantee idempotency during network transmissions1.  
Next, the background synchronization worker is instantiated. This worker continuously polls the sync\_outbox table. For each pending row, the worker formats an API call to the Supabase backend. If the HTTP transmission succeeds, the row is permanently deleted from the local outbox. If the transmission fails due to network instability, the worker increments the attempt\_count on the row and applies an exponential backoff algorithm (e.g., waiting two minutes, then four minutes, then eight minutes) before attempting the transmission again, preventing battery drain in areas with zero connectivity1.  
Finally, an authentication migration routine must be implemented. When a guest user authenticates via Google OAuth, the system intercepts the state change. A script queries all local Drift tables containing the temporary guest UUID, updates the records to the new authoritative auth.uid(), and forces an immediate outbox flush to upload the retained offline history to the cloud1.

### **Phase 3: Android Alarm Management and Full-Screen Intents**

Bypassing the device lock screen natively requires deep integration with the Android operating system using Method Channels, as standard Flutter local notification plugins cannot reliably circumvent modern battery optimization restrictions24.  
The alarm scheduling mechanism utilizes the android\_alarm\_manager\_plus package, invoking Android's AlarmManager.setExactAndAllowWhileIdle() API. The system passes a PendingIntent that resolves to a native Kotlin BroadcastReceiver when the scheduled time arrives23.  
To successfully break through the lock screen, the native MainActivity.kt file must be heavily modified. When the BroadcastReceiver is triggered, it launches the MainActivity. In Android 14 and higher, the onCreate method must detect the operating system version and apply the necessary window flags and Keyguard dismissals. The Kotlin implementation explicitly sets setShowWhenLocked(true) and setTurnScreenOn(true), while requesting the KeyguardManager to dismiss the lock screen. Additionally, the FLAG\_KEEP\_SCREEN\_ON parameter is applied to ensure the device does not sleep while the user is performing their exercises14.  
Handling Android 14's strict Full-Screen Intent (FSI) restrictions is critical. In the Flutter layer, a lifecycle check must invoke a Method Channel to call NotificationManager.canUseFullScreenIntent(). If the operating system returns false, the application must immediately launch an intent directing the user to the Settings.ACTION\_MANAGE\_APP\_USE\_FULL\_SCREEN\_INTENT menu. If the user refuses to grant this permission, the system must gracefully degrade its behavior, posting a high-priority Heads-Up Notification (HUN) paired with a persistent, loud audio channel instead of attempting a direct screen takeover4.

### **Phase 4: ML Kit Pose Detection and Biomechanical Verification**

The core gamification loop relies entirely on validating exercise form using the Google ML Kit vision pipeline.  
Developers must configure the camera package to stream raw image bytes in the optimal format for the target platform (YUV\_420\_888 for Android, BGRA8888 for iOS). These byte streams are piped directly into the google\_mlkit\_pose\_detection instance. Crucially, the Pose Detector must be instantiated using STREAM\_MODE. This configuration ensures that ML Kit tracks the primary subject continuously across sequential frames rather than executing a computationally expensive full-person detection algorithm on every individual frame, which drastically reduces latency and mitigates CPU thermal throttling16.  
Once the 33 skeletal landmarks are extracted, the system calculates the required biomechanical joint angles26. For example, to validate a squat, the system calculates the angle between the hip, knee, and ankle. The angle ![][image1] between three coordinates ![][image2], ![][image3], and ![][image4] (where ![][image3] represents the knee vertex) is calculated utilizing vector dot products:  
![][image5]  
![][image6]  
![][image7]  
The exercise state machine registers a "Down" state when ![][image8] and transitions back to an "Up" state when ![][image9], successfully iterating the repetition counter15.  
To provide visual feedback, the system renders a skeletal overlay using a CustomPainter to draw lines between the interconnected joints. To maintain a fluid 60 frames per second (FPS), developers must avoid wrapping the entire camera view in setState. Instead, the architecture passes a ValueNotifier\<Pose\> directly to the CustomPainter's repaint argument. This instructs the underlying Flutter rendering engine (Skia or Impeller) to repaint only the specific canvas layer, completely bypassing expensive widget tree rebuilds51.

### **Phase 5: Background Location Tracking and Kalman Filtering**

Mapping competitive territories requires precise, continuous background GPS tracking while simultaneously mitigating the inherent jitter of satellite telemetry.  
The location module initializes a foreground service utilizing the flutter\_foreground\_task package, detaching the location polling loop from the main user interface isolate. This service displays a persistent notification, which is an absolute requirement to prevent the Android operating system from terminating the process to reclaim RAM while the device is locked in the user's pocket27.  
Anti-cheat measures must be integrated directly into the polling loop. As the Geolocator fetches coordinates, the system inspects the position.isMocked boolean. If true, the system detects a GPS spoofing application and instantly invalidates the run data. Furthermore, the system analyzes the speed parameter derived from the location delta; if the velocity continuously exceeds reasonable human sprinting speeds, the system suspends territory capture, preventing users from claiming areas while driving9.  
Because raw GPS data inherently zig-zags due to atmospheric interference, the raw coordinates are fed into a 4D Extended Kalman Filter provided by the kalman\_dr package. The filter applies a recursive algorithm consisting of a prediction phase (utilizing the current speed and heading) and an update phase (correcting the prediction based on the new, noisy GPS fix). This algorithmic processing eliminates the jitter, producing a beautifully smoothed geometric path that is critical for accurate polygon drawing7.

### **Phase 6: Territory Capture and PostGIS Geometric Operations**

Converting a runner's path into competitive territory logic relies heavily on the advanced geospatial capabilities of the Supabase PostGIS backend.  
On the client side, the application monitors the distance between the starting coordinate and the current location. If the user travels a minimum threshold distance and subsequently returns within a 30-meter radius of the origin point, the UI flags the path as a valid loop. The client then transmits the array of LineString coordinates to a Supabase RPC edge function.  
Within the Postgres database, the PostGIS extension snaps the start and end points of the LineString together to force mathematical closure. The system utilizes ST\_MakePolygon(ST\_AddPoint(path, ST\_StartPoint(path))) to generate the raw polygon57. Because human runners frequently cross their own paths, the raw polygon may contain self-intersections, rendering it mathematically invalid for area calculations. The SQL function resolves this by applying ST\_Buffer(geom, 0\) or ST\_CollectionHomogenize to dissolve the kinks and extract the valid outer hull of the captured territory60.  
Finally, the backend calculates the competitive turf wars. If the newly generated polygon overlaps an existing territory owned by a rival user, the database executes a slicing operation. The RPC invokes ST\_Difference(Rival\_Geom, New\_Geom) to subtract the invaded area from the rival's territory. It subsequently updates the new user's polygon and recalculates the total area owned by both users in square meters utilizing the ST\_Area function, completing the gamification loop13.

#### **Works cited**

1. Offline-First Flutter: Drift as the Source of Truth, Supabase as a Sync Target \- Medium, [https://medium.com/@fintasys/offline-first-flutter-drift-as-the-source-of-truth-supabase-as-a-sync-target-eab7c43523ce](https://medium.com/@fintasys/offline-first-flutter-drift-as-the-source-of-truth-supabase-as-a-sync-target-eab7c43523ce)  
2. Offline-First Flutter: Implementation Blueprint for Real-World Apps \- GeekyAnts, [https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps](https://geekyants.com/blog/offline-first-flutter-implementation-blueprint-for-real-world-apps)  
3. Flutter Outbox Pattern \- DEV Community, [https://dev.to/guimg/flutter-outbox-pattern-16m3](https://dev.to/guimg/flutter-outbox-pattern-16m3)  
4. Full-screen intent limits \- Android Open Source Project, [https://source.android.com/docs/core/permissions/fsi-limits](https://source.android.com/docs/core/permissions/fsi-limits)  
5. Full-Screen Intent (FSI) Notifications in Android 14 & 15: What Changed, Why It's Breaking, and How to Fix It | by Subhankar Bag | ProAndroidDev, [https://proandroiddev.com/full-screen-intent-fsi-notifications-in-android-14-15-what-changed-why-its-breaking-and-e5e862a75936](https://proandroiddev.com/full-screen-intent-fsi-notifications-in-android-14-15-what-changed-why-its-breaking-and-e5e862a75936)  
6. Flutter GPS AR Fusion App \- GitHub, [https://github.com/IoT-gamer/flutter\_gps\_ar\_fusion\_app](https://github.com/IoT-gamer/flutter_gps_ar_fusion_app)  
7. kalman\_dr | Dart package \- Pub.dev, [https://pub.dev/packages/kalman\_dr](https://pub.dev/packages/kalman_dr)  
8. Implementing a Kalman Filter in Postgres to Smooth GPS Data \- Neon, [https://neon.com/blog/implementing-a-kalman-filter-in-postgres-to-smooth-gps-data](https://neon.com/blog/implementing-a-kalman-filter-in-postgres-to-smooth-gps-data)  
9. geolocator changelog | Flutter package \- Pub.dev, [https://pub.dev/packages/geolocator/changelog](https://pub.dev/packages/geolocator/changelog)  
10. How to detect Mock location in Flutter using Geolocator Plugin \- Stack Overflow, [https://stackoverflow.com/questions/66347602/how-to-detect-mock-location-in-flutter-using-geolocator-plugin](https://stackoverflow.com/questions/66347602/how-to-detect-mock-location-in-flutter-using-geolocator-plugin)  
11. Detect mock location in flutter \- gps \- Stack Overflow, [https://stackoverflow.com/questions/71478581/detect-mock-location-in-flutter](https://stackoverflow.com/questions/71478581/detect-mock-location-in-flutter)  
12. [https://drive.google.com/open?id=1Bp0\_otXugr5rCDeUBgRhmfdWGIn0PNsCqk\_WYQS4lOY](https://drive.google.com/open?id=1Bp0_otXugr5rCDeUBgRhmfdWGIn0PNsCqk_WYQS4lOY)  
13. DAUDLO / RunFit \- GitHub, [https://github.com/nagasriramnani/RunFit](https://github.com/nagasriramnani/RunFit)  
14. Android, How to launch Activity over Lock screen \- Stack Overflow, [https://stackoverflow.com/questions/35356848/android-how-to-launch-activity-over-lock-screen](https://stackoverflow.com/questions/35356848/android-how-to-launch-activity-over-lock-screen)  
15. Pose classification options | ML Kit \- Google for Developers, [https://developers.google.com/ml-kit/vision/pose-detection/classifying-poses](https://developers.google.com/ml-kit/vision/pose-detection/classifying-poses)  
16. Detect poses with ML Kit on Android \- Google for Developers, [https://developers.google.com/ml-kit/vision/pose-detection/android](https://developers.google.com/ml-kit/vision/pose-detection/android)  
17. GitHub \- ShiBui2003/stride · GitHub, [https://github.com/ShiBui2003/stride](https://github.com/ShiBui2003/stride)  
18. Background location tracking | ArcGIS Maps SDK for Flutter \- Esri Developer, [https://developers.arcgis.com/flutter/device-location/background-location-tracking/](https://developers.arcgis.com/flutter/device-location/background-location-tracking/)  
19. Keep the screen on | Background work \- Android Developers, [https://developer.android.com/develop/background-work/background-tasks/awake/screen-on](https://developer.android.com/develop/background-work/background-tasks/awake/screen-on)  
20. Android O \- FLAG\_SHOW\_WHEN\_LOCKED is deprecated \- Stack Overflow, [https://stackoverflow.com/questions/48277302/android-o-flag-show-when-locked-is-deprecated](https://stackoverflow.com/questions/48277302/android-o-flag-show-when-locked-is-deprecated)  
21. Building Offline-First Flutter Apps: A Complete Sync Solution with Drift | by 777genius, [https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0](https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0)  
22. flutter\_local\_notifications | Flutter package \- Pub.dev, [https://pub.dev/packages/flutter\_local\_notifications](https://pub.dev/packages/flutter_local_notifications)  
23. Schedule alarms | Background work \- Android Developers, [https://developer.android.com/develop/background-work/services/alarms](https://developer.android.com/develop/background-work/services/alarms)  
24. Applinx-Tech/Flutter-Alarm-Manager-POC: A Flutter App POC to display full screen notifications in lock screen and handling notifications even in app killed state \- GitHub, [https://github.com/Applinx-Tech/Flutter-Alarm-Manager-POC](https://github.com/Applinx-Tech/Flutter-Alarm-Manager-POC)  
25. ML Kit Pose Detection Makes Staying Active at Home Easier, [https://developers.googleblog.com/ml-kit-pose-detection-makes-staying-active-at-home-easier/](https://developers.googleblog.com/ml-kit-pose-detection-makes-staying-active-at-home-easier/)  
26. Pose detection | ML Kit \- Google for Developers, [https://developers.google.com/ml-kit/vision/pose-detection](https://developers.google.com/ml-kit/vision/pose-detection)  
27. Implementing Background Location Tracking in Flutter: A Step-by-Step Guide \- Medium, [https://medium.com/@tungenwarkartick/implementing-background-location-tracking-in-flutter-a-step-by-step-guide-4ac3d6f5fb92](https://medium.com/@tungenwarkartick/implementing-background-location-tracking-in-flutter-a-step-by-step-guide-4ac3d6f5fb92)  
28. Hologres:PostGIS spatial functions \- Alibaba Cloud, [https://www.alibabacloud.com/help/en/hologres/developer-reference/postgis-for-geographic-information-analysis](https://www.alibabacloud.com/help/en/hologres/developer-reference/postgis-for-geographic-information-analysis)  
29. Feature-First Clean Architecture for Flutter \- Medium, [https://medium.com/@remy.baudet/feature-first-clean-architecture-for-flutter-246366e71c18](https://medium.com/@remy.baudet/feature-first-clean-architecture-for-flutter-246366e71c18)  
30. Clean Architecture in Flutter 2026 \- Practical Implementation Guide \- DEV Community, [https://dev.to/techwithsam/clean-architecture-in-flutter-2026-practical-implementation-guide-1dfb](https://dev.to/techwithsam/clean-architecture-in-flutter-2026-practical-implementation-guide-1dfb)  
31. Mastering Flutter Architecture: From CLEAN to Feature-First for Faster, Scalable Development \- DEV Community, [https://dev.to/princetomarappdev/mastering-flutter-architecture-from-clean-to-feature-first-for-faster-scalable-development-4605](https://dev.to/princetomarappdev/mastering-flutter-architecture-from-clean-to-feature-first-for-faster-scalable-development-4605)  
32. Strengthening Flutter Application Security: A Developer's Guide \- Logique Digital Indonesia, [https://www.logique.co.id/blog/en/2025/03/26/strengthening-flutter-application-security/](https://www.logique.co.id/blog/en/2025/03/26/strengthening-flutter-application-security/)  
33. live\_location\_tracker\_plus | Flutter package \- Pub.dev, [https://pub.dev/packages/live\_location\_tracker\_plus](https://pub.dev/packages/live_location_tracker_plus)  
34. Implementing Android Notification Channels, Actions, Scheduling, and Permissions in Flutter Using… \- Shubham Agrawal, [https://buildwithshubham.medium.com/implementing-android-notification-channels-actions-scheduling-and-permissions-in-flutter-using-07fb958f4c66](https://buildwithshubham.medium.com/implementing-android-notification-channels-actions-scheduling-and-permissions-in-flutter-using-07fb958f4c66)  
35. Advanced Location Tracking in Flutter: The Complete 2026 Guide \- Medium, [https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558)  
36. Flutter : Building Offline-First Apps with Supabase \- Dev Adnani, [https://www.devadnani.com/blog/flutter-offline-first-supabase](https://www.devadnani.com/blog/flutter-offline-first-supabase)  
37. offline\_first\_sync\_drift 0.1.1 | Dart package \- Pub.dev, [https://pub.dev/packages/offline\_first\_sync\_drift/versions/0.1.1](https://pub.dev/packages/offline_first_sync_drift/versions/0.1.1)  
38. offline\_first\_sync\_drift example | Dart package \- Pub.dev, [https://pub.dev/packages/offline\_first\_sync\_drift/example](https://pub.dev/packages/offline_first_sync_drift/example)  
39. google\_mlkit\_pose\_detection | Flutter package \- pub.dev, [https://pub.dev/packages/google\_mlkit\_pose\_detection](https://pub.dev/packages/google_mlkit_pose_detection)  
40. The Calimiro mobile app\! \- GitHub, [https://github.com/calimiro-ai/calimiro\_app](https://github.com/calimiro-ai/calimiro_app)  
41. Build an Exercise Detector and Counter App in Flutter with Pose Detection | by Hamza Asif, [https://hamzaasif-mobileml.medium.com/build-an-exercise-detector-and-counter-app-in-flutter-with-pose-detection-59b4002f1b48](https://hamzaasif-mobileml.medium.com/build-an-exercise-detector-and-counter-app-in-flutter-with-pose-detection-59b4002f1b48)  
42. flutter\_foreground\_task \- Flutter package in Android/iOS Device Software & Hardware category, [https://fluttergems.dev/packages/flutter\_foreground\_task/](https://fluttergems.dev/packages/flutter_foreground_task/)  
43. flutter\_foreground\_task | Flutter package \- Pub.dev, [https://pub.dev/packages/flutter\_foreground\_task](https://pub.dev/packages/flutter_foreground_task)  
44. Turf Alternatives \- JavaScript Maps | LibHunt, [https://js.libhunt.com/turf-alternatives](https://js.libhunt.com/turf-alternatives)  
45. Turf.js Intersecting buffer with Polygon,MultiPolygon,GeometryCollection \- Stack Overflow, [https://stackoverflow.com/questions/40211522/turf-js-intersecting-buffer-with-polygon-multipolygon-geometrycollection](https://stackoverflow.com/questions/40211522/turf-js-intersecting-buffer-with-polygon-multipolygon-geometrycollection)  
46. Architecture case study \- Flutter documentation, [https://docs.flutter.dev/app-architecture/case-study](https://docs.flutter.dev/app-architecture/case-study)  
47. Displaying Full screen notifications in Lock Screen from Flutter app : r/FlutterDev \- Reddit, [https://www.reddit.com/r/FlutterDev/comments/1k140g5/displaying\_full\_screen\_notifications\_in\_lock/](https://www.reddit.com/r/FlutterDev/comments/1k140g5/displaying_full_screen_notifications_in_lock/)  
48. Finding the angle between three points? \- Mathematics Stack Exchange, [https://math.stackexchange.com/questions/361412/finding-the-angle-between-three-points](https://math.stackexchange.com/questions/361412/finding-the-angle-between-three-points)  
49. Using the law of cosines and vector dot product formula to find the angle between three points \- Muthukrishnan, [https://muthu.co/using-the-law-of-cosines-and-vector-dot-product-formula-to-find-the-angle-between-three-points/](https://muthu.co/using-the-law-of-cosines-and-vector-dot-product-formula-to-find-the-angle-between-three-points/)  
50. How to calculate an angle from three points? \[closed\] \- Stack Overflow, [https://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points](https://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points)  
51. CustomPainter in Flutter: The Most Underused Power Tool \- Mantra Ideas, [https://mantraideas.com/flutter-custompainter-complete-guide/](https://mantraideas.com/flutter-custompainter-complete-guide/)  
52. Mastering Flutter CustomPainter \- Medium, [https://yashashm.medium.com/mastering-flutter-custompainter-b7fa6b4de6df](https://yashashm.medium.com/mastering-flutter-custompainter-b7fa6b4de6df)  
53. Flutter CustomPainter Tutorial: SVGs, Animations & Advanced Painting, [https://verygood.ventures/blog/mastering-custompainter-in-flutter-from-svgs-to-racetracks/](https://verygood.ventures/blog/mastering-custompainter-in-flutter-from-svgs-to-racetracks/)  
54. CustomPainter class \- rendering library \- Dart API \- Flutter, [https://api.flutter.dev/flutter/rendering/CustomPainter-class.html](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)  
55. Drawing Custom Shapes With CustomPainter in Flutter \- Kodeco, [https://www.kodeco.com/7560981-drawing-custom-shapes-with-custompainter-in-flutter/page/2](https://www.kodeco.com/7560981-drawing-custom-shapes-with-custompainter-in-flutter/page/2)  
56. GPS Data with Kalman Filtering, [https://cerv.aut.ac.nz/wp-content/uploads/2025/08/GPS-1.html](https://cerv.aut.ac.nz/wp-content/uploads/2025/08/GPS-1.html)  
57. PostGIS 1.5 Manual, [http://postgis.net/stuff/archive/postgis-1.5.pdf](http://postgis.net/stuff/archive/postgis-1.5.pdf)  
58. PostGIS 2.5.9dev Manual, [https://postgis.net/stuff/postgis-2.5.pdf](https://postgis.net/stuff/postgis-2.5.pdf)  
59. Chapter 7\. PostGIS Reference, [https://postgis.net/docs/manual-1.4/ch07.html](https://postgis.net/docs/manual-1.4/ch07.html)  
60. Eliminate overlaps and gaps between polygons in a layer (with QGis and Geopackage) | Blog GIS & Territories, [https://www.sigterritoires.fr/index.php/en/eliminate-overlaps-and-gaps-between-polygons-in-a-layer-with-qgis-and-geopackage/](https://www.sigterritoires.fr/index.php/en/eliminate-overlaps-and-gaps-between-polygons-in-a-layer-with-qgis-and-geopackage/)  
61. Chapter 7\. PostGIS Reference, [https://postgis.net/docs/reference.html](https://postgis.net/docs/reference.html)  
62. Using JSTS buffer to identify a self-intersecting polygon \- Stack Overflow, [https://stackoverflow.com/questions/36118883/using-jsts-buffer-to-identify-a-self-intersecting-polygon](https://stackoverflow.com/questions/36118883/using-jsts-buffer-to-identify-a-self-intersecting-polygon)  
63. turf.js Intersect Error for Self-intersecting Polygons from OpenLayers3 Draw \- Stack Overflow, [https://stackoverflow.com/questions/38599863/turf-js-intersect-error-for-self-intersecting-polygons-from-openlayers3-draw](https://stackoverflow.com/questions/38599863/turf-js-intersect-error-for-self-intersecting-polygons-from-openlayers3-draw)  
64. Chapter 8\. PostGIS Special Functions Index, [https://postgis.net/docs/manual-1.5/ch08.html](https://postgis.net/docs/manual-1.5/ch08.html)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAbCAYAAABFuB6DAAAA/ElEQVR4Xu3RMUuCQRzH8X+gkBQoOFTQUkMQtIWbrW5ODQm+hZx7Hy1BBE3R0hoELm5BtPQCGgxBHNzSoUH9/p6707tnCxoa/MEHz//zv3vunjP7V9nAERrYyj1bpoQb3KGDV+wnHaSIW9z78SaecRU3KRcY4cT/1xYePI2zVPGGRxR8bRs9T+MsLcz8b8ge+hatqBW00hCHqz6rYYrrUNjBJ37wFfnGHO3QeIqJRTPNveUJYxyHYtNyM8kBBpYe7neN2rQ2H6LTq3YW1axu7kNrr4qu8cXcVS5XU3Tqd3MT9L0u0UU5bgo5x4e5k+p+d9PHaXRNlXxxnb/NAniLLenUuJJVAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAbCAYAAACjkdXHAAAA7UlEQVR4Xu2SvQtBURiHXwNRiokUJhOjldFosbLblcgqkzJZDTKYjHab1T9gIGU0WUj8Xue659xzv2TUfeqpc9+Pc+55O0R/TQYOYFJP+BGCQ3iCWS3nSxleDXn9NTG4gEd4hxVr2psGHMM+fMK6Ne1OCq5gDvZINDctFR50YctY84nczJv4UiJx17jx/WkemRUuhOEUVpUYD4oHNldijtTgg8RJumsYlaV2fm5OwCUsaHF+nge4ITkHGx3Y1oMkm/cwreXe75eHsoN5LcfwH21JbMAbmfBULyTvdYZFJT+BNyXP6xmMKDUBAc68ALggNDDdcTA1AAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAZCAYAAADXPsWXAAAA/ElEQVR4Xu2SwQoBURSGj9goWUkpRYryABaUB7BgK09g5RlseAFZKcnCI9hYeQIrslJIJMlGShH/deYy9xozS5v56mum+e/t3HvOELk4kYNr+DB5hlvj/Q6HMCU32NGCF5jRvifhAs5hVMsUAnAMZzCkRi/6xKcq6oGZBNzBHvRomSxwhVk1UikRV6rqASgT96UNfVqm0CSuVIARwxiswz2sQO97tQXyuAfi63QMu8Q9asCgXPwLu37EiSczgWE1UrHrh0BORlzVEqfR5ol7NSJea0kaHuGA1KuIJorKJzglbvIXosKKPr+5GOGG+PcXzxtcwhr08xYXlz/xBB76OKePI6vzAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAaCAYAAAC+aNwHAAABE0lEQVR4Xu3TP0tCURjH8SciKBIiBEkolGzR3oEQhDg0BrW3utpUIdHi2NDkElFtvYAImkRBh95BTkLUHtJgYH0f7rmmD8c/c/iDDxzOc+659/y5Iv8+EeziEGnMu/5lrLu2Nxk00cEDjnGPZ2zjCfn+6IEsoIQuTrA0XJYdfOJNPF+gD1fwjQNTC7OIR0fbQyngB6eYM7XB3OHMdm7hHS1smJrNtXjWfyHB28um35cVCZbbjx5VFT3xzDxN4mjjA5umNlXCCZS2x0U3Oms7V/EikyeI4gYxW9BcSrAHe7bgoseqt3HU/ZAEXlHDmqnpbTxHUcbfD0migS/c4ghXqCMnEx4Oo4OS2HdS8vcHzjLLyPwC1vkp/WcUoisAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAyCAYAAADhjoeLAAACWUlEQVR4Xu3bzatNURgH4CUfESUlIiZmTAzMxJwBo1smpmJMEpn6KxhcSUoYMb+ZKiMmZkwMhAkT8vG+rbOz7rrHLfeeU7s8T/06Z717n332mr2ttXcpAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACMxr7Ijb44B6f7AgDA/+pj5H4zvhm50ox7XyeZpzuRu31xnQ6XOtcNk/HGyK+y+lwBAEYhm5aLzfhYZCmyo6kNtkXeRb73B2bsVeRRZFN/YB3OljrXVjaeS10NAGBUsil7Hdnd1J5HjjbjwZ7I48i1srLxmaVLpW67vojs6o6tx1Kpcx3sjHwo0+cKADAahyJPIvtLbZJOTsbTXI2cj5wp82vYDpa6PZuN5NtS72lW3pc6t7xm5mXkwLIzAABG6FapW6CDfL5rWjO2udRmLp0o89sSvV3qf+VWaG5Xtvc2yOND09UnVwH/pr/e9ciFZgwAMErtQ/iDn5GtXe1B8z0bo1z9mvaMWz7I3zdRbab9ZnCuLL+XbBxzNW8W8oWDXLlrr38q8qysnCsAwKj0q2m5evWjq6X2pYShYdvb1AbbIwurJBunaXJr8mFXy3u73NXWKl84aOeQ8v+yDgAwSouRL6U2RfnWZ+Zb5GlzTvpc6jn5/Ncgz8tafm5p6mt1r9Trtc3jm6Z2vKn/q1w9Wyz1Op9KnWd+5r0f+XMaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABj8RsxXFMXGK0ylAAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAyCAYAAADhjoeLAAACrklEQVR4Xu3cP8gURxgH4AkqKBFEFMWYgKhNQLEQtbKxkJQBg42RlGkDFlpYpLG00EYRERs7tVIEbT4U0qS20kJFTBUE0UAMSXxfZ5dvb/yDevvhic8DP+5mZneP6V5mdq4UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+ulWRvZENkS+69kJYHvkhsqhrfz0YAwD4LP0ZuTBoH40cGrS/jDwt8wVU+jFya9Ce1pJSf/dIZFnXtzvypIxXsC2NXC2Tz3sWuT5oAwDMpP8jPw/a2yNzpa50rYhci+wcjKfVkZNN3zRORf5p+voCKz/HsD5yr0w+b67Uog0AYGZlUXa71AKsdzOyrfv+d6lFTSvv+7bt/ECbI3ci37QD4WzbMYXDkf8G7dzWzWL1l0EfAMDM2Ri5HPkqsq7Ubchsp8WlFjQHuvZQFjvDLdJp/Bo51nZ2coVvLBcjf5Q6z8yZyJ5S5wIAMLOyUMot0F6/6pSy//fIyvnhBXG/1MLxXeX7bn3R1WbN4LpWbrnmKltvV+RSmX9nDgBgJuWBg3aFKbcN8z2vLKLmSt3+HMotzNNNXy+vbYuoYV63KpdFYY61zpW3F2DvI+fzsEweOFhb6vzH2toFAFgQ/WpaL1ev/u2+Z5HzOLJlfvil4+XVQwi9raX+Jceb8rrVrHzed01fFpH7mr5p5IGD9gBDnnTNww659QsAMHPOl/pXHVmwPejyPHJlcE3aEbkbOVHqPTcmRsfzW+SvyE+l/la+WzaWg6XOM+eX83xUalG6f3gRAMCnLLcxc3UsDya026djyeduiHwf2TQ5BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMKoXUAVN3IgP6BQAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,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>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE0AAAAaCAYAAADygtH/AAADQUlEQVR4Xu2YS6iNURTH1w1F3o88ysCVRyKRJOWVJJJHrjxvxEASGaGkDGRCFANKSpIopreUATIgJAYoJZFHFCMMDPD/37UX+9vn7vM9zunWrf2vX+d++9vf+fb+77XW3ueKJCUl9SC1gElgKegf3EvqQv3AOXAB7AX3wdhMj+5VL7AejAvaTRzvZnAeHAeTs7c7xSCYA86As2CF6Pf6mgkug+tgvugzhdRH9OUX3d99QQc46HfqBtGIleA0+AB+gFmZHqrB4BY4CgaAGeAFaPP6cPIHwF3QCoaDK6Lz5BypqWCXqJHsz+cXuXu52gA+g2numl/AF5DCzudooNSuciiatlx04EckbhoX8xEY6rVtAS/BKHfN5zinef96iIwHb8Eyd71Jst8/Buz3rqPiCjwEV0Fv18bVu+Pg31Vl6XEbnBQ1pahoTFem0Sgadilonw2+g1Xu+pioQTTCxIW7J5pRHBtr90Lv/kTQ7l1HtRH8dp8mvogvrBppjKjV4AE4LLowZRUzbQr4KrWmsR/70ywrL6FpFgwWpVxE9l8rWs9YG5n6dcXIYoR9Eg1dE1ftp2gBLSPWCpr/BOyTxnbgmGlmTsw0tps5MdP8dgYFF3Wk5JePTjH/X4Nf4J0Hw/yPaJ0oIq7YDvDUfZZJw5hipnGj4NjqmWaZUsS00rIX+RHF6LshmgJMhXpiJDGiGFmMMNuVmqGYadwo8kyzYAjNaYpptmp+RLWC95LdGGLaDl6J1oRCoV1CMdOanZ6lRdNYu1jDTIwYtrEwFpEfbVulOalJxUxj7WUNjpl2SP5nS2iOmcYdlDtpJfEMw7OMDYwTvin6yyAvykJZXeMhs9FNgIqZZhPvEN0lTUtEazM/KT4flpgR4LmU3+AyYu4/FjWvBewRPWnnbrt1FB43BmVvFxYnHWaBiWcpblgsJRTHzl8HfKeNfYJomfGPUsyeL2Cu11ZJbeCZaDhz9UZnb1cWzVssmgonpNhZjdF5DXwTrbXGR3DK68cNh9nAQ/MaUcMYQfw55Yu19g3YCbaJZsFuqXb2rBFDfkjY2CRxgNNFJz0suNeI+L38j8w6sEDiOzcXi7WbFFm4pKSkpKSkpKSkHqi/XyCu03uisekAAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAE0AAAAaCAYAAADygtH/AAADRklEQVR4Xu2YW6hNQRjHP6HIPXIpypFLIpeQiIiIJHJyV96QyJNblCcPKOVeKEmiiBcninLkgfBAuTxJ5BLiQXjwgP+/b772rLX37L3WOvucqPnXr73XzOw1M//1zXyztkhUVNR/pHZgOJgLuqTqoiqoMzgBToPN4B4YmGjRtmoPloHBqXJfHPMqcBLslfLxMggmg8PgOFggel9f48E5cAlMF/1NJnUU7fiM+94JNIHtfqM2EE1YCA6Bd+AHmJBoUdJI8BjsFDVrKXgA+rp6Tn4buAMaQG9wXnSenCM1CmwQNZLtG8FMV1dTy8FHMNpd8wbsgFRznkvYBlAP0bT5ogPfI2HTaMxTUcM4Po7jliTb85NzmuauqSHgNZjnrldK8v4DwFbvOig+AT6hC6CDK+sKmh38HtJUcBdskfrvgYzykGms+yIababZYIeo8RSXKw2iEaZuouPliqLZ3LtnePXDwBrvOqgV4Lf7NLEjdlgr0iiG9izRwRwQfQj1UMi0HuA+eCjaF2Hk+XuVbS9p0ywY+NteogbT3CWi+9l+0ftXFSOLEfZBNHRNk8BP0Q00q2zTvQ2OSnKwRRQyjdHFKKNxx8AucAQ8A+NcGzMnZJpfznFXMj6ofuAl+AXeeHwHf8DqUtPM4iDGgOvgMhiRrM6skGm8ZjlXByOEYp/7wAvRpGArJYtpuWUD8COK0cfJpveMIqJhvNcV9z2PapnGyOrjlTPr8kGvl1IwpM2pi2nWkR9RDeCtJBNDS8T70bSroGeqrppCpo0F36Q8Sdlczrpy1qfNCZXnEjvi3sU9zMSEwDJujC0RI4sHRpI3yqiQaRZFzRI2zVZL2hwzjUmLmbSQeIbhWcYGxmxyQ/TNoEiU2X52DZwSjbKiCplmycsyoMlfnlSlYwmXM5d1ngRXJj61R6LmccKbwE3JkHZTao1jByedXgWmOeCzlAxNJwJqqOg24x+luHo+gSleWSE1giei4dwE+ierq4pmLRJN/7tB92R1bvGAfBF8FY0a4z046LXjWwj7ewXWiR45aNBErw3F7Gpt1oLnYKPUPntmEtd6nk3axPe21ngbyKpBYLFU/1eGUc+lS+qxAqKioqKioqKiov5B/QUlmq/MWf1AiAAAAABJRU5ErkJggg==>