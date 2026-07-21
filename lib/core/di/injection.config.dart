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
import '../../features/alarm/domain/usecases/reconcile_recurring_alarms.dart'
    as _i273;
import '../../features/alarm/domain/usecases/schedule_alarm.dart' as _i528;
import '../../features/alarm/domain/usecases/watch_alarms.dart' as _i396;
import '../../features/alarm/domain/usecases/watch_current_streak.dart'
    as _i416;
import '../../features/alarm/domain/usecases/watch_current_tax_multiplier.dart'
    as _i893;
import '../../features/alarm/domain/usecases/watch_ringing_alarm.dart' as _i879;
import '../../features/alarm/presentation/bloc/alarm_cubit.dart' as _i268;
import '../../features/onboarding/data/repositories/battery_exemption_repository_impl.dart'
    as _i694;
import '../../features/onboarding/domain/repositories/battery_exemption_repository.dart'
    as _i162;
import '../../features/onboarding/domain/usecases/check_battery_exemption_status.dart'
    as _i823;
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
import '../platform/system_capabilities.dart' as _i703;
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
  gh.lazySingleton<_i96.AlarmLocalDataSource>(
    () => _i96.AlarmLocalDataSource(),
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
  gh.lazySingleton<_i355.LocalWriter>(
    () => _i355.LocalWriter(gh<_i90.AppDatabase>()),
  );
  gh.lazySingleton<_i162.BatteryExemptionRepository>(
    () => _i694.BatteryExemptionRepositoryImpl(gh<_i703.SystemCapabilities>()),
  );
  gh.factory<_i349.VerificationCubit>(
    () => _i349.VerificationCubit(
      gh<_i188.StartVerificationSession>(),
      gh<_i547.StopVerificationSession>(),
      gh<_i703.WatchVerificationState>(),
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
  gh.lazySingleton<_i487.AuthRepository>(
    () => _i1.AuthRepositoryImpl(gh<_i670.AuthRemoteDataSource>()),
  );
  gh.lazySingleton<_i959.WakeUpTaxStore>(
    () => _i959.WakeUpTaxStore(gh<_i90.AppDatabase>(), gh<_i355.LocalWriter>()),
  );
  gh.factory<_i688.EnsureAuthSession>(
    () => _i688.EnsureAuthSession(gh<_i487.AuthRepository>()),
  );
  gh.lazySingleton<_i1014.AlarmRepository>(
    () => _i153.AlarmRepositoryImpl(
      gh<_i96.AlarmLocalDataSource>(),
      gh<_i355.LocalWriter>(),
      gh<_i90.AppDatabase>(),
      gh<_i959.WakeUpTaxStore>(),
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
  gh.factory<_i273.ReconcileRecurringAlarms>(
    () => _i273.ReconcileRecurringAlarms(gh<_i1014.AlarmRepository>()),
  );
  gh.factory<_i528.ScheduleAlarm>(
    () => _i528.ScheduleAlarm(gh<_i1014.AlarmRepository>()),
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
    ),
  );
  return getIt;
}

class _$RegisterModule extends _i291.RegisterModule {}
