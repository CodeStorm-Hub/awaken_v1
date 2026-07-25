import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/injection.dart';
import 'core/usecase/usecase.dart';
import 'features/alarm/data/datasources/alarm_local_datasource.dart';
import 'features/alarm/domain/usecases/reconcile_recurring_alarms.dart';
import 'features/alarm/domain/usecases/rearm_alarms_from_cache.dart';
import 'features/profile/domain/usecases/ensure_auth_session.dart';
import 'features/profile/domain/usecases/refresh_auth_session.dart';
import 'features/territory/data/datasources/location_provider_factory.dart';
import 'sync/outbox/sync_worker.dart';
import 'sync/pull/pull_down_sync.dart';

/// Keys that must never leave the device in a Sentry event/breadcrumb —
/// GPS coordinates/paths and anything camera/pose-frame related. Checked
/// case-insensitively against every key found (recursively) in event
/// extras, contexts, and breadcrumb data, since these can originate from
/// many call sites (territory RPC payloads, location provider errors,
/// pose-detector exceptions) rather than one choke point.
const _sensitiveDataKeys = {
  'lat',
  'lng',
  'latitude',
  'longitude',
  'path',
  'points',
  'coordinates',
  'geojson',
  'p_path',
  'frame',
  'image',
  'bytes',
};

Map<String, dynamic>? _scrubSensitiveKeys(Map<String, dynamic>? data) {
  if (data == null) return null;
  final scrubbed = <String, dynamic>{};
  for (final entry in data.entries) {
    if (_sensitiveDataKeys.contains(entry.key.toLowerCase())) {
      scrubbed[entry.key] = '[redacted]';
    } else if (entry.value is Map<String, dynamic>) {
      scrubbed[entry.key] = _scrubSensitiveKeys(entry.value as Map<String, dynamic>);
    } else {
      scrubbed[entry.key] = entry.value;
    }
  }
  return scrubbed;
}

/// Shared bootstrap for both flavors. See main_dev.dart / main_prod.dart.
///
/// [locationProviderOverride] is only ever passed by `main_e2e.dart` — a
/// plain post-DI `getIt` re-registration (not an injectable environment),
/// so it needs no code generation to swap in `ScriptedLocationProvider` for
/// Appium E2E runs on both Android and real iOS hardware.
Future<void> bootstrap({
  required String envFile,
  LocationProviderFactory? locationProviderOverride,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load(fileName: envFile);

  // Wraps the entire remaining bootstrap sequence (not just runApp) so
  // pre-runApp crashes — e.g. AlarmLocalDataSource.init() or
  // ReconcileRecurringAlarms throwing before any UI exists (a real gap the
  // review flagged) — are actually captured instead of silently killing
  // the process with no recovery screen and no record of why.
  // `dsn: Env.sentryDsn ?? ''` makes this a safe no-op until a real Sentry
  // project is provisioned — the SDK still installs FlutterError/zone
  // handlers, it just never sends.
  await SentryFlutter.init(
    (options) {
      options.dsn = Env.sentryDsn ?? '';
      // Conservative default — this is a small early-stage app, not a
      // high-traffic service; keep sampling cheap until there's a reason
      // to tune it against real event volume.
      options.tracesSampleRate = 0.2;
      // Last line of defense before anything leaves the device — strips
      // GPS/frame data from event extras and breadcrumb data even if a
      // future call site accidentally attaches raw domain payloads (e.g.
      // `Sentry.captureException(e, extra: trackPoint.toJson())`).
      options.beforeSend = (event, hint) {
        // `extra` is soft-deprecated in favor of structured `Contexts`, but
        // it's still the field `beforeSend` scrubbing conventionally
        // targets, and nothing in this codebase writes to `contexts` with
        // domain data — `extra` is the actual risk surface here.
        // ignore: deprecated_member_use
        event.extra = _scrubSensitiveKeys(event.extra);
        return event;
      };
      options.beforeBreadcrumb = (breadcrumb, hint) {
        breadcrumb?.data = _scrubSensitiveKeys(breadcrumb.data);
        return breadcrumb;
      };
    },
    appRunner: () => _bootstrapApp(locationProviderOverride: locationProviderOverride),
  );
}

Future<void> _bootstrapApp({LocationProviderFactory? locationProviderOverride}) async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  await configureDependencies();

  if (locationProviderOverride != null) {
    getIt.unregister<LocationProviderFactory>();
    getIt.registerLazySingleton<LocationProviderFactory>(
      () => locationProviderOverride,
    );
  }

  // Android 13+ blocks ALL notifications — including the alarm's
  // full-screen-intent notification — until POST_NOTIFICATIONS is granted
  // at runtime; declaring it in the manifest alone does nothing. Requested
  // bluntly here for now; a proper rationale screen belongs in the
  // onboarding carousel (plan §5) before the OS dialog fires.
  await Permission.notification.request();

  // Restores/reschedules any alarms persisted from a previous session —
  // must run before the UI reads Alarm.scheduled/Alarm.ringing.
  await getIt<AlarmLocalDataSource>().init();

  // Self-heal for recurring alarms (plan discussion — "hybrid" rescheduling
  // approach): fixes up any recurring alarm whose post-ring reschedule
  // never ran (app killed/crashed right after a ring).
  await getIt<ReconcileRecurringAlarms>()(const NoParams());

  // Guarantee every user has a real auth.uid() from first launch (plan
  // H8) — signs in anonymously if online and no session exists yet. If
  // this fails (offline first launch), the app still starts; features
  // that need auth.uid() should retry via the same use case later.
  try {
    await getIt<EnsureAuthSession>()(const NoParams());

    // Cold-launch counterpart to the app-resume refresh in app.dart's
    // `_StartupFlowState` — a locally-persisted session carries whatever
    // JWT claims it had at last refresh, so a user who linked email/Google,
    // force-quit the app, and relaunched would otherwise keep seeing
    // "Guest" until the SDK's own background refresh timer eventually
    // fires. Cheap no-op if there's no session yet.
    await getIt<RefreshAuthSession>()(const NoParams());

    // Reinstall/new-device hydration (plan §6 Phase 6.5) — no-ops if the
    // local cache is already populated. Re-arms any alarm the pull
    // hydrated that wasn't previously scheduled natively.
    await getIt<PullDownSync>().run();
    await getIt<RearmAlarmsFromCache>()(const NoParams());
  } catch (_) {
    // TODO(Phase 3b): offline-first-launch fallback — local placeholder
    // UUID + re-key routine (plan §2.2 H8, kept only as a fallback).
  }

  // Connectivity-triggered outbox drain (plan §3, ADR-002) — safe to start
  // even without a session yet; SyncWorker no-ops until one exists.
  getIt<SyncWorker>().start();

  runApp(const AwakenApp());
}
