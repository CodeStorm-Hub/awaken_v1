// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../features/alarm/data/datasources/alarm_local_datasource.dart'
    as _i96;
import '../../features/alarm/data/datasources/wake_up_tax_store.dart' as _i959;
import '../../features/alarm/data/repositories/alarm_repository_impl.dart'
    as _i153;
import '../../features/alarm/domain/repositories/alarm_repository.dart'
    as _i1014;
import '../../features/alarm/domain/usecases/cancel_alarm.dart' as _i915;
import '../../features/alarm/domain/usecases/complete_alarm_workout.dart'
    as _i738;
import '../../features/alarm/domain/usecases/dismiss_alarm.dart' as _i735;
import '../../features/alarm/domain/usecases/rearm_alarms_from_cache.dart'
    as _i278;
import '../../features/alarm/domain/usecases/reconcile_recurring_alarms.dart'
    as _i273;
import '../../features/alarm/domain/usecases/schedule_alarm.dart' as _i528;
import '../../features/alarm/domain/usecases/set_alarm_active.dart' as _i1064;
import '../../features/alarm/domain/usecases/watch_alarms.dart' as _i396;
import '../../features/alarm/domain/usecases/watch_current_streak.dart'
    as _i416;
import '../../features/alarm/domain/usecases/watch_current_tax_multiplier.dart'
    as _i893;
import '../../features/alarm/domain/usecases/watch_ringing_alarm.dart' as _i879;
import '../../features/alarm/presentation/bloc/alarm_cubit.dart' as _i268;
import '../../features/home/data/repositories/home_activity_repository_impl.dart'
    as _i79;
import '../../features/home/domain/repositories/home_activity_repository.dart'
    as _i468;
import '../../features/home/domain/usecases/watch_recent_activity.dart'
    as _i135;
import '../../features/onboarding/data/datasources/onboarding_local_datasource.dart'
    as _i804;
import '../../features/onboarding/data/repositories/battery_exemption_repository_impl.dart'
    as _i694;
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart'
    as _i452;
import '../../features/onboarding/domain/repositories/battery_exemption_repository.dart'
    as _i162;
import '../../features/onboarding/domain/repositories/onboarding_repository.dart'
    as _i430;
import '../../features/onboarding/domain/usecases/check_battery_exemption_status.dart'
    as _i823;
import '../../features/onboarding/domain/usecases/has_seen_onboarding.dart'
    as _i81;
import '../../features/onboarding/domain/usecases/mark_onboarding_seen.dart'
    as _i522;
import '../../features/onboarding/domain/usecases/open_oem_autostart_settings.dart'
    as _i486;
import '../../features/onboarding/domain/usecases/request_battery_exemption.dart'
    as _i476;
import '../../features/profile/data/datasources/auth_remote_datasource.dart'
    as _i670;
import '../../features/profile/data/repositories/auth_repository_impl.dart'
    as _i1;
import '../../features/profile/domain/repositories/auth_repository.dart'
    as _i487;
import '../../features/profile/domain/usecases/ensure_auth_session.dart'
    as _i688;
import '../../features/profile/domain/usecases/link_with_email.dart' as _i243;
import '../../features/profile/domain/usecases/link_with_google.dart' as _i343;
import '../../features/profile/domain/usecases/sign_out.dart' as _i487;
import '../../features/profile/domain/usecases/watch_current_user.dart'
    as _i560;
import '../../features/squad/data/datasources/squad_remote_datasource.dart'
    as _i654;
import '../../features/squad/data/repositories/squad_repository_impl.dart'
    as _i235;
import '../../features/squad/domain/repositories/squad_repository.dart'
    as _i1051;
import '../../features/squad/domain/usecases/create_squad.dart' as _i134;
import '../../features/squad/domain/usecases/join_squad.dart' as _i36;
import '../../features/squad/domain/usecases/leave_squad.dart' as _i769;
import '../../features/squad/domain/usecases/watch_leaderboard.dart' as _i670;
import '../../features/squad/domain/usecases/watch_my_rank.dart' as _i343;
import '../../features/squad/domain/usecases/watch_my_squad.dart' as _i871;
import '../../features/squad/domain/usecases/watch_squad_presence.dart'
    as _i597;
import '../../features/squad/presentation/bloc/squad_cubit.dart' as _i635;
import '../../features/territory/data/datasources/run_foreground_service.dart'
    as _i862;
import '../../features/territory/data/datasources/territory_remote_datasource.dart'
    as _i246;
import '../../features/territory/data/repositories/run_tracking_repository_impl.dart'
    as _i501;
import '../../features/territory/data/repositories/territory_repository_impl.dart'
    as _i18;
import '../../features/territory/domain/repositories/run_tracking_repository.dart'
    as _i175;
import '../../features/territory/domain/repositories/territory_repository.dart'
    as _i706;
import '../../features/territory/domain/usecases/abandon_run.dart' as _i773;
import '../../features/territory/domain/usecases/capture_run.dart' as _i125;
import '../../features/territory/domain/usecases/refresh_territories.dart'
    as _i490;
import '../../features/territory/domain/usecases/start_run.dart' as _i592;
import '../../features/territory/domain/usecases/watch_owned_area.dart'
    as _i838;
import '../../features/territory/domain/usecases/watch_run_state.dart' as _i256;
import '../../features/territory/domain/usecases/watch_territories.dart'
    as _i38;
import '../../features/territory/presentation/bloc/run_tracking_cubit.dart'
    as _i3;
import '../../features/verification/data/datasources/camera_datasource.dart'
    as _i311;
import '../../features/verification/data/datasources/pose_detector_datasource.dart'
    as _i587;
import '../../features/verification/data/repositories/pose_verification_repository_impl.dart'
    as _i265;
import '../../features/verification/domain/repositories/pose_verification_repository.dart'
    as _i5;
import '../../features/verification/domain/usecases/start_verification_session.dart'
    as _i188;
import '../../features/verification/domain/usecases/stop_verification_session.dart'
    as _i547;
import '../../features/verification/domain/usecases/watch_verification_state.dart'
    as _i703;
import '../../features/verification/presentation/bloc/verification_cubit.dart'
    as _i349;
import '../../sync/connectivity/connectivity_watcher.dart' as _i1036;
import '../../sync/local/database.dart' as _i90;
import '../../sync/outbox/local_writer.dart' as _i355;
import '../../sync/outbox/sync_worker.dart' as _i666;
import '../../sync/pull/pull_down_sync.dart' as _i1039;
import '../platform/system_capabilities.dart' as _i703;
import '../theme/theme_mode_cubit.dart' as _i947;
import 'register_module.dart' as _i291;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final registerModule = _$RegisterModule();
  gh.lazySingleton<_i454.SupabaseClient>(() => registerModule.supabaseClient);
  gh.lazySingleton<_i90.AppDatabase>(() => registerModule.appDatabase);
  gh.lazySingleton<_i703.SystemCapabilities>(() => _i703.SystemCapabilities());
  gh.lazySingleton<_i947.ThemeModeCubit>(() => _i947.ThemeModeCubit());
  gh.lazySingleton<_i96.AlarmLocalDataSource>(
    () => _i96.AlarmLocalDataSource(),
  );
  gh.lazySingleton<_i804.OnboardingLocalDataSource>(
    () => _i804.OnboardingLocalDataSource(),
  );
  gh.lazySingleton<_i862.RunForegroundService>(
    () => _i862.RunForegroundService(),
  );
  gh.lazySingleton<_i311.CameraDataSource>(() => _i311.CameraDataSource());
  gh.lazySingleton<_i587.PoseDetectorDataSource>(
    () => _i587.PoseDetectorDataSource(),
  );
  gh.lazySingleton<_i1036.ConnectivityWatcher>(
    () => _i1036.ConnectivityWatcher(),
  );
  gh.lazySingleton<_i666.SyncWorker>(
    () => _i666.SyncWorker(
      gh<_i90.AppDatabase>(),
      gh<_i454.SupabaseClient>(),
      gh<_i1036.ConnectivityWatcher>(),
    ),
  );
  gh.factory<_i246.TerritoryRemoteDataSource>(
    () => _i246.TerritoryRemoteDataSource(gh<_i454.SupabaseClient>()),
  );
  gh.lazySingleton<_i654.SquadRemoteDataSource>(
    () => _i654.SquadRemoteDataSource(gh<_i454.SupabaseClient>()),
  );
  gh.lazySingleton<_i706.TerritoryRepository>(
    () => _i18.TerritoryRepositoryImpl(
      gh<_i246.TerritoryRemoteDataSource>(),
      gh<_i90.AppDatabase>(),
      gh<_i454.SupabaseClient>(),
    ),
  );
  gh.lazySingleton<_i670.AuthRemoteDataSource>(
    () => _i670.AuthRemoteDataSource(gh<_i454.SupabaseClient>()),
  );
  gh.lazySingleton<_i5.PoseVerificationRepository>(
    () => _i265.PoseVerificationRepositoryImpl(
      gh<_i311.CameraDataSource>(),
      gh<_i587.PoseDetectorDataSource>(),
    ),
  );
  gh.factory<_i188.StartVerificationSession>(
    () => _i188.StartVerificationSession(gh<_i5.PoseVerificationRepository>()),
  );
  gh.factory<_i547.StopVerificationSession>(
    () => _i547.StopVerificationSession(gh<_i5.PoseVerificationRepository>()),
  );
  gh.factory<_i703.WatchVerificationState>(
    () => _i703.WatchVerificationState(gh<_i5.PoseVerificationRepository>()),
  );
  gh.lazySingleton<_i1039.PullDownSync>(
    () =>
        _i1039.PullDownSync(gh<_i90.AppDatabase>(), gh<_i454.SupabaseClient>()),
  );
  gh.lazySingleton<_i468.HomeActivityRepository>(
    () => _i79.HomeActivityRepositoryImpl(gh<_i90.AppDatabase>()),
  );
  gh.lazySingleton<_i430.OnboardingRepository>(
    () => _i452.OnboardingRepositoryImpl(gh<_i804.OnboardingLocalDataSource>()),
  );
  gh.lazySingleton<_i355.LocalWriter>(
    () => _i355.LocalWriter(gh<_i90.AppDatabase>()),
  );
  gh.lazySingleton<_i162.BatteryExemptionRepository>(
    () => _i694.BatteryExemptionRepositoryImpl(gh<_i703.SystemCapabilities>()),
  );
  gh.factory<_i490.RefreshTerritories>(
    () => _i490.RefreshTerritories(gh<_i706.TerritoryRepository>()),
  );
  gh.factory<_i838.WatchOwnedArea>(
    () => _i838.WatchOwnedArea(gh<_i706.TerritoryRepository>()),
  );
  gh.factory<_i38.WatchTerritories>(
    () => _i38.WatchTerritories(gh<_i706.TerritoryRepository>()),
  );
  gh.lazySingleton<_i1051.SquadRepository>(
    () => _i235.SquadRepositoryImpl(
      gh<_i654.SquadRemoteDataSource>(),
      gh<_i454.SupabaseClient>(),
    ),
  );
  gh.factory<_i823.CheckBatteryExemptionStatus>(
    () => _i823.CheckBatteryExemptionStatus(
      gh<_i162.BatteryExemptionRepository>(),
    ),
  );
  gh.factory<_i486.OpenOemAutostartSettings>(
    () =>
        _i486.OpenOemAutostartSettings(gh<_i162.BatteryExemptionRepository>()),
  );
  gh.factory<_i476.RequestBatteryExemption>(
    () => _i476.RequestBatteryExemption(gh<_i162.BatteryExemptionRepository>()),
  );
  gh.factory<_i349.VerificationCubit>(
    () => _i349.VerificationCubit(
      gh<_i188.StartVerificationSession>(),
      gh<_i547.StopVerificationSession>(),
      gh<_i703.WatchVerificationState>(),
      gh<_i1051.SquadRepository>(),
    ),
  );
  gh.lazySingleton<_i487.AuthRepository>(
    () => _i1.AuthRepositoryImpl(gh<_i670.AuthRemoteDataSource>()),
  );
  gh.lazySingleton<_i959.WakeUpTaxStore>(
    () => _i959.WakeUpTaxStore(gh<_i90.AppDatabase>(), gh<_i355.LocalWriter>()),
  );
  gh.factory<_i134.CreateSquad>(
    () => _i134.CreateSquad(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i36.JoinSquad>(
    () => _i36.JoinSquad(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i769.LeaveSquad>(
    () => _i769.LeaveSquad(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i670.WatchLeaderboard>(
    () => _i670.WatchLeaderboard(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i343.WatchMyRank>(
    () => _i343.WatchMyRank(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i871.WatchMySquad>(
    () => _i871.WatchMySquad(gh<_i1051.SquadRepository>()),
  );
  gh.factory<_i597.WatchSquadPresence>(
    () => _i597.WatchSquadPresence(gh<_i1051.SquadRepository>()),
  );
  gh.lazySingleton<_i175.RunTrackingRepository>(
    () => _i501.RunTrackingRepositoryImpl(
      gh<_i862.RunForegroundService>(),
      gh<_i355.LocalWriter>(),
      gh<_i666.SyncWorker>(),
      gh<_i90.AppDatabase>(),
    ),
  );
  gh.factory<_i81.HasSeenOnboarding>(
    () => _i81.HasSeenOnboarding(gh<_i430.OnboardingRepository>()),
  );
  gh.factory<_i522.MarkOnboardingSeen>(
    () => _i522.MarkOnboardingSeen(gh<_i430.OnboardingRepository>()),
  );
  gh.factory<_i773.AbandonRun>(
    () => _i773.AbandonRun(gh<_i175.RunTrackingRepository>()),
  );
  gh.factory<_i125.CaptureRun>(
    () => _i125.CaptureRun(gh<_i175.RunTrackingRepository>()),
  );
  gh.factory<_i592.StartRun>(
    () => _i592.StartRun(gh<_i175.RunTrackingRepository>()),
  );
  gh.factory<_i256.WatchRunState>(
    () => _i256.WatchRunState(gh<_i175.RunTrackingRepository>()),
  );
  gh.factory<_i135.WatchRecentActivity>(
    () => _i135.WatchRecentActivity(gh<_i468.HomeActivityRepository>()),
  );
  gh.factory<_i688.EnsureAuthSession>(
    () => _i688.EnsureAuthSession(gh<_i487.AuthRepository>()),
  );
  gh.factory<_i243.LinkWithEmail>(
    () => _i243.LinkWithEmail(gh<_i487.AuthRepository>()),
  );
  gh.factory<_i343.LinkWithGoogle>(
    () => _i343.LinkWithGoogle(gh<_i487.AuthRepository>()),
  );
  gh.factory<_i487.SignOut>(() => _i487.SignOut(gh<_i487.AuthRepository>()));
  gh.factory<_i560.WatchCurrentUser>(
    () => _i560.WatchCurrentUser(gh<_i487.AuthRepository>()),
  );
  gh.lazySingleton<_i1014.AlarmRepository>(
    () => _i153.AlarmRepositoryImpl(
      gh<_i96.AlarmLocalDataSource>(),
      gh<_i355.LocalWriter>(),
      gh<_i90.AppDatabase>(),
      gh<_i959.WakeUpTaxStore>(),
    ),
  );
  gh.factory<_i635.SquadCubit>(
    () => _i635.SquadCubit(
      gh<_i871.WatchMySquad>(),
      gh<_i134.CreateSquad>(),
      gh<_i36.JoinSquad>(),
      gh<_i769.LeaveSquad>(),
      gh<_i670.WatchLeaderboard>(),
      gh<_i597.WatchSquadPresence>(),
    ),
  );
  gh.factory<_i3.RunTrackingCubit>(
    () => _i3.RunTrackingCubit(
      gh<_i592.StartRun>(),
      gh<_i773.AbandonRun>(),
      gh<_i125.CaptureRun>(),
      gh<_i256.WatchRunState>(),
      gh<_i1051.SquadRepository>(),
    ),
  );
  gh.factory<_i915.CancelAlarm>(
    () => _i915.CancelAlarm(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i738.CompleteAlarmWorkout>(
    () => _i738.CompleteAlarmWorkout(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i735.DismissAlarm>(
    () => _i735.DismissAlarm(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i278.RearmAlarmsFromCache>(
    () => _i278.RearmAlarmsFromCache(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i273.ReconcileRecurringAlarms>(
    () => _i273.ReconcileRecurringAlarms(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i528.ScheduleAlarm>(
    () => _i528.ScheduleAlarm(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i1064.SetAlarmActive>(
    () => _i1064.SetAlarmActive(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i396.WatchAlarms>(
    () => _i396.WatchAlarms(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i416.WatchCurrentStreak>(
    () => _i416.WatchCurrentStreak(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i893.WatchCurrentTaxMultiplier>(
    () => _i893.WatchCurrentTaxMultiplier(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i879.WatchRingingAlarm>(
    () => _i879.WatchRingingAlarm(gh<_i1014.AlarmRepository>()),
  );
  gh.lazySingleton<_i268.AlarmCubit>(
    () => _i268.AlarmCubit(
      gh<_i396.WatchAlarms>(),
      gh<_i879.WatchRingingAlarm>(),
      gh<_i528.ScheduleAlarm>(),
      gh<_i915.CancelAlarm>(),
      gh<_i735.DismissAlarm>(),
      gh<_i738.CompleteAlarmWorkout>(),
      gh<_i893.WatchCurrentTaxMultiplier>(),
      gh<_i1064.SetAlarmActive>(),
    ),
  );
  return getIt;
}

class _$RegisterModule extends _i291.RegisterModule {}
