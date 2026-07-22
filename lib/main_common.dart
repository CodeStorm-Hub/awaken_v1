import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/injection.dart';
import 'core/usecase/usecase.dart';
import 'features/alarm/data/datasources/alarm_local_datasource.dart';
import 'features/alarm/domain/usecases/reconcile_recurring_alarms.dart';
import 'features/alarm/domain/usecases/rearm_alarms_from_cache.dart';
import 'features/profile/domain/usecases/ensure_auth_session.dart';
import 'sync/outbox/sync_worker.dart';
import 'sync/pull/pull_down_sync.dart';

/// Shared bootstrap for both flavors. See main_dev.dart / main_prod.dart.
Future<void> bootstrap({required String envFile}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load(fileName: envFile);
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  await configureDependencies();

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
