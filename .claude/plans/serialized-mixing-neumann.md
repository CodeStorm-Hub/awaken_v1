# Fix verification-session camera teardown noise, missing outcome telemetry, dismiss-time jank

## Context

Reviewed `workout_logs.md` (a real device log of one alarm ring → pose-verification → dismiss
cycle) plus the verification feature code (`lib/features/verification/**`,
`lib/features/alarm/**`). Three real issues surfaced, confirmed against code, and researched
against current (mid-2026) upstream guidance for `camera`/`camera_android_camerax`,
`camera_avfoundation`, and `google_mlkit_pose_detection`:

1. Every camera teardown (end of a verification session) spams
   `E/BufferQueueProducer: dequeueBuffer: BufferQueue has been abandoned` — hundreds of lines,
   twice per session in the log. Confirmed as a known, still-open upstream CameraX/Flutter
   `camera` plugin behavior (flutter/flutter #132499 "unawaited calls to stop async camera
   operations" — marked done but the underlying native ImageReader-vs-BufferQueue teardown
   ordering is still async/best-effort; flutter/flutter #149807 documents `stopImageStream()` +
   `dispose()` not being a clean, instant teardown on iOS either). Our `pubspec.lock` is already
   on the newest `camera 0.12.0+2` / `camera_android_camerax 0.7.4+2` — this isn't an app version
   bug, and there's no documented app-level ordering that eliminates it, only mitigates its
   window and its blast radius on the UI thread.
2. No log line (app-level or Sentry) exists anywhere for a completed/failed/cancelled
   verification session — `PoseVerificationRepositoryImpl` only pushes to an in-app
   `StreamController`, never to Sentry. Every other repository in this codebase that has a
   real-world outcome worth auditing (`alarm_repository_impl.dart`) already reports through
   `Sentry.captureMessage`/`addBreadcrumb`. Verification — the actual anti-cheat gate for
   dismissing an alarm — currently reports nothing, so a real "did they actually do the reps"
   question is unanswerable from telemetry.
3. `Choreographer: Skipped 34 frames!` lands in the log at the exact moment the "Done" button's
   `Navigator.pop` tears down `VerificationPage` (celebration dialog dismiss + new MapLibre
   surface stand-up in the same window as camera disposal). `VerificationCubit.close()` awaits
   `_stopSession()` → `_camera.stop()` → `stopImageStream()` + `dispose()`, all triggered
   synchronously off the widget-tree teardown that `Navigator.pop` causes. That's the same
   camera-teardown work from issue 1 landing on the main thread during a navigation transition.

## Fix 1 — Camera teardown noise + its main-thread cost (Android + iOS)

The `BufferQueueProducer` spam itself is native-side CameraX log noise, not a Dart-catchable
exception, and not fixable by call reordering (ours is already the documented-correct
`stopImageStream()` → `dispose()` order in
[camera_datasource.dart](lib/features/verification/data/datasources/camera_datasource.dart:49)).
The actionable fix is to get that teardown off the critical path of `VerificationCubit.close()`
so it can no longer contribute to a dropped-frame moment during the dismiss→celebration→map
transition, on both platforms (the datasource has no platform branch for `stop()`, so this
applies equally to Android CameraX and iOS AVFoundation backends):

- In [verification_cubit.dart](lib/features/verification/presentation/bloc/verification_cubit.dart:108),
  change `close()` so `_stopSession()` is fired via `unawaited(...)` instead of `await`ed before
  `super.close()` returns. `_generation`-guarded frame handling in
  `PoseVerificationRepositoryImpl` already makes this safe — a straggling frame from the
  about-to-be-disposed camera is discarded, not acted on (see the existing `_generation` doc
  comment at [pose_verification_repository_impl.dart:52](lib/features/verification/data/repositories/pose_verification_repository_impl.dart:52)).
  `WakelockPlus.disable()` can stay awaited since it's cheap and not camera-related.
- Bump `camera`/`camera_android_camerax` to whatever is newest at implementation time via
  `flutter pub upgrade camera` (already-tracked upstream fixes land in point releases; re-check
  `pubspec.lock` after) — cheap to do, no code change required, worth doing opportunistically
  since we're already touching this area.
- Do not attempt to suppress/catch the log line itself — it's emitted by native code below the
  plugin boundary; trying to silence it would just be hiding a real (harmless) async-teardown
  signal.
- iOS-specific check (per CLAUDE.md's standing instruction not to assume Android patterns
  transfer): `camera_avfoundation`'s dispose path is a different native implementation
  (`AVCaptureSession.stopRunning`) with its own documented async-teardown/race history
  (flutter/flutter #132073, the `_captureSessionQueue` nil-out race fixed via PR #4619 upstream).
  The `unawaited(_stopSession())` change in the cubit benefits both backends identically since
  it's platform-agnostic Dart code sitting above both; no iOS-only code path is needed.

## Fix 2 — Verification-outcome telemetry (Sentry, matching existing convention)

Add breadcrumbs to `PoseVerificationRepositoryImpl` mirroring the pattern already used in
[alarm_repository_impl.dart:73-84](lib/features/alarm/data/repositories/alarm_repository_impl.dart:73)
(`Sentry.captureMessage`/breadcrumb with `withScope` tags, wrapped in `unawaited(...)`). Use
`Sentry.addBreadcrumb` (not `captureMessage`) for the routine start/complete/cancel path since
these aren't failures — they should show up attached to any *later* error in the same session,
and also be independently queryable as breadcrumb-only events if Sentry's breadcrumb-as-event
capture is enabled. Add breadcrumbs at:
- `start()`: exercise mode + target reps.
- `_handleUsablePose()`'s `done` branch (session reached `VerificationStatus.complete`): reps
  completed, exercise mode.
- `stop()`: whether it was reached via a completed session or an early exit (needs a flag/param
  threaded from `VerificationCubit` — `stop()` currently has no way to distinguish "user tapped
  Done after completing" from "user backed out mid-session"; add an optional
  `completed: bool` param to `PoseVerificationRepository.stop()`/`StopVerificationSession`,
  defaulting to inferring from `_state.isComplete` if not passed).
- `VerificationStatus.cameraError` emission in `start()`'s catch block: currently swallows the
  underlying exception entirely (`catch (_)`) — capture it via `Sentry.captureException` instead
  of discarding, since "camera failed to start" during a real alarm dismiss is exactly the kind
  of failure worth knowing rate/frequency of in production.

## Verification

- `flutter analyze` — no new lint issues.
- `flutter test test/features/verification/` (check existing test coverage for
  `PoseVerificationRepositoryImpl`/`VerificationCubit` first; extend rather than duplicate).
- Manual device run (`flutter run --flavor dev -t lib/main_dev.dart`) per CLAUDE.md's standing
  rule that alarm/camera-lifecycle behavior must be verified on a real device, not just
  `flutter analyze`: schedule a short alarm, let it ring, go through a full verification session
  (complete it), confirm:
  - `adb logcat` still shows the `BufferQueueProducer` spam (expected, unfixed at the source) but
    it no longer straddles the `Choreographer: Skipped N frames!` warning the way it did before —
    re-check for a jank warning in the same window as the Done-button transition.
  - Sentry (dev project) shows the new breadcrumbs/captured exception for a deliberately forced
    camera error (e.g. another app holding the camera) and for a normal completed session.
  - Repeat once on a real iOS device/simulator with camera access, since `camera_datasource.dart`
    and `verification_cubit.dart` are platform-agnostic Dart — confirm the AVFoundation backend
    doesn't newly regress (no crash, no hang) from the `unawaited` change.
