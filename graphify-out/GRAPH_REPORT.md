# Graph Report - .  (2026-08-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 3590 nodes · 5287 edges · 187 communities (174 shown, 13 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0d86b490`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- database.dart
- territory_page.dart
- app_localizations.dart
- _
- app_localizations_en.dart
- territory_map_style.dart
- active_run_page.dart
- package:injectable/injectable.dart
- verification_page.dart
- expressive_widgets.dart
- rep_counter.dart
- package:flutter/material.dart
- StatelessWidget
- home_page.dart
- core/usecase/usecase.dart
- territory_repository.dart
- semantic_colors.dart
- alarm_repository_impl.dart
- run_tracking_repository_impl.dart
- Mock
- onboarding_page.dart
- auth_dialog.dart
- squad_repository_impl.dart
- alarm_cubit.dart
- alarm_ring_page.dart
- @injectable
- home_cubit_test.dart
- leaderboards_sheet.dart
- map_style_loader.dart
- run_tracking_repository.dart
- battery_exemption_page.dart
- AppDatabase
- home_page_test.dart
- run_tracking_repository_impl_test.dart
- alarm_repository.dart
- squad_remote_datasource.dart
- squad_loaded_view.dart
- app_shell_page.dart
- sync_worker.dart
- home_cubit.dart
- profile_page.dart
- alarm_list_page.dart
- pose_mapper.dart
- squad_cubit.dart
- squad_cubit_test.dart
- alarm_card.dart
- auth_repository_impl.dart
- alarm_repository_impl_test.dart
- AppDelegate.swift
- territory_repository_impl.dart
- schedule_sheet.dart
- run_track_state.dart
- VoidCallback
- auth_repository.dart
- auth_remote_datasource.dart
- app.dart
- ../../../../core/theme/expressive_widgets.dart
- app_constants.dart
- Color
- pose_verification_repository_impl.dart
- State
- verification_cubit.dart
- home_state.dart
- auth_dialog_test.dart
- auth_repository_impl_test.dart
- workout_celebration_sheet.dart
- conquest_ticker.dart
- onboarding_repository_impl.dart
- run_tracking_cubit.dart
- check_battery_exemption_status.dart
- DataClass
- main_common.dart
- String?
- alarm_reliability_test_page.dart
- squad_repository_impl_test.dart
- territory_repository_impl_test.dart
- territories_table.dart
- shape_tokens.dart
- List
- squad_repository.dart
- text_prompt_dialog.dart
- runs_table.dart
- rep_counter_test.dart
- ../../../alarm/domain/entities/alarm_schedule.dart
- verification_state.dart
- compilerOptions
- motion_tokens.dart
- scripted_location_provider.dart
- MainActivity
- gamification_widgets.dart
- DateTime
- package:drift/drift.dart
- squad_presence_member.dart
- ../repositories/squad_repository.dart
- app_theme.dart
- sync_outbox_table.dart
- edit_name_dialog.dart
- battery_exemption_repository_impl.dart
- map_style_overlays.dart
- google_logo.dart
- alarm_state.dart
- SquadRepository
- src/index.ts
- run_foreground_service.dart
- package:flutter_bloc/flutter_bloc.dart
- SquadCubit
- alarm_schedule.dart
- alarms_table.dart
- package:flutter_test/flutter_test.dart
- weekly_reset_ceremony_gate.dart
- account_actions_section.dart
- rise_in.dart
- watch_recent_activity.dart
- static const
- home_activity_repository_impl.dart
- devDependencies
- squad_state.dart
- failures.dart
- wake_up_tax_store.dart
- territory_capture_feed_item.dart
- squad_page_shared.dart
- profile_cubit.dart
- kalman_golden_trajectory_test.dart
- geolocator_location_provider.dart
- package.json
- env.dart
- system_capabilities.dart
- leaderboard_entry.dart
- run_capture_result.dart
- pull_down_sync.dart
- pulsing_dot.dart
- skeleton_painter.dart
- territory_remote_datasource.dart
- Equatable
- location_provider_factory.dart
- territory.dart
- alarm_payload.dart
- complete_alarm_workout.dart
- package:supabase_flutter/supabase_flutter.dart
- delete_account_dialog.dart
- rival.dart
- sessions_table.dart
- local_writer.dart
- Table
- camera_datasource.dart
- path_simplifier.dart
- settings_row.dart
- get_nearby_leaderboard.dart
- track_point.dart
- ../../core/constants/app_constants.dart
- get_global_leaderboard.dart
- main_e2e.dart
- connectivity_watcher.dart
- start_verification_session.dart
- bounty_zone.dart
- injection.dart
- android_management_mcp_proxy.js
- expressive_fab.dart
- geo_bounds.dart
- pose_detector_datasource.dart
- dart:async
- territory_mapper.dart
- get_recent_territory_captures.dart
- gps_quality.dart
- AppLocalizations
- exclude
- get_my_squad_rank.dart
- _TerritoryPageState
- weekday_labels.dart
- _RepCounterState
- main.dart
- generate_basemap.sh
- _ExpressiveLoaderState
- AuthDialog
- CreateSquad
- JoinSquad
- WatchLeaderboard
- WatchSquadPresence
- RunProgressRemoteDataSource
- outbox_operation.dart
- @example
- bool?

## God Nodes (most connected - your core abstractions)
1. `_` - 201 edges
2. `UseCase` - 32 edges
3. `AlarmCubit` - 24 edges
4. `SquadRepository` - 21 edges
5. `AppDatabase` - 20 edges
6. `AlarmRepository` - 19 edges
7. `SquadCubit` - 18 edges
8. `AuthRepository` - 16 edges
9. `VerificationCubit` - 16 edges
10. `compilerOptions` - 15 edges

## Surprising Connections (you probably didn't know these)
- `_FakeAlarmCubit` --implements--> `AlarmCubit`  [EXTRACTED]
  test/features/alarm/alarm_list_page_test.dart → lib/features/alarm/presentation/bloc/alarm_cubit.dart
- `_FakeAlarmCubit` --implements--> `AlarmCubit`  [EXTRACTED]
  test/features/home/presentation/pages/home_page_test.dart → lib/features/alarm/presentation/bloc/alarm_cubit.dart
- `_FakeHomeCubit` --implements--> `HomeCubit`  [EXTRACTED]
  test/features/home/presentation/pages/home_page_test.dart → lib/features/home/presentation/bloc/home_cubit.dart
- `FakeLinkWithEmail` --implements--> `LinkWithEmail`  [EXTRACTED]
  test/features/profile/presentation/widgets/auth_dialog_test.dart → lib/features/profile/domain/usecases/link_with_email.dart
- `FakeLinkWithGoogle` --implements--> `LinkWithGoogle`  [EXTRACTED]
  test/features/profile/presentation/widgets/auth_dialog_test.dart → lib/features/profile/domain/usecases/link_with_google.dart

## Import Cycles
- None detected.

## Communities (187 total, 13 thin omitted)

### Community 0 - "database.dart"
Cohesion: 0.02
Nodes (131): class RunCheckpointRow extends, ColumnFilters, ColumnOrderings, GeneratedColumn, GeneratedDatabase, _, actualTableName, alarmId (+123 more)

### Community 1 - "territory_page.dart"
Cohesion: 0.02
Nodes (127): active_run_page.dart, ../../domain/usecases/get_active_bounty_zones.dart, ../../domain/usecases/get_current_position.dart, ../../domain/usecases/get_current_rival.dart, ../../domain/usecases/get_territories_at_risk.dart, _animateCaptureGrowIn, _antPathDashSequence, _antPathStep (+119 more)

### Community 2 - "app_localizations.dart"
Cohesion: 0.02
Nodes (96): app_localizations_en.dart, addAlarmSemanticLabel, addAlarmTitle, alarmCardSemanticLabel, alarmDeleted, alarmDeleteFailed, alarmDismissed, alarmDismissedSubtitle (+88 more)

### Community 3 - "_"
Cohesion: 0.02
Nodes (91): ../../features/alarm/data/datasources/wake_up_tax_store.dart, ../../features/alarm/data/repositories/alarm_repository_impl.dart, ../../features/alarm/domain/repositories/alarm_repository.dart, ../../features/alarm/domain/usecases/cancel_alarm.dart, ../../features/alarm/domain/usecases/cancel_all_alarms.dart, ../../features/alarm/domain/usecases/complete_alarm_workout.dart, ../../features/alarm/domain/usecases/dismiss_alarm.dart, ../../features/alarm/domain/usecases/schedule_alarm.dart (+83 more)

### Community 4 - "app_localizations_en.dart"
Cohesion: 0.02
Nodes (86): app_localizations.dart, addAlarmSemanticLabel, addAlarmTitle, alarmCardSemanticLabel, alarmDeleted, alarmDeleteFailed, alarmDismissed, alarmDismissedSubtitle (+78 more)

### Community 5 - "territory_map_style.dart"
Cohesion: 0.02
Nodes (82): apply, applyCityBuildings, _applyToPresent, atRiskIds, avatarPuckIconNamePrefix, _boundaryColor, _buildingColorDark, _buildingColorLight (+74 more)

### Community 6 - "active_run_page.dart"
Cohesion: 0.03
Nodes (74): ../bloc/run_tracking_cubit.dart, Circle?, ../../domain/usecases/refresh_territories.dart, ../../domain/usecases/watch_territories.dart, LatLng, RunTrackState, RunTrackingCubit, _abandon (+66 more)

### Community 7 - "package:injectable/injectable.dart"
Cohesion: 0.07
Nodes (30): ../entities/app_user.dart, AuthRepositoryImpl, AuthRepository, call, _repository, call, _repository, call (+22 more)

### Community 8 - "verification_page.dart"
Cohesion: 0.07
Nodes (38): ../bloc/verification_cubit.dart, ../../data/datasources/camera_datasource.dart, ../../domain/entities/verification_result.dart, VerificationState, VerificationCubit, build, _buildBanner, _buildContent (+30 more)

### Community 9 - "expressive_widgets.dart"
Cohesion: 0.05
Nodes (38): EdgeInsetsGeometry?, animatePop, avatarInitial, avatarUrl, bg, blurAmount, borderColor, borderRadius (+30 more)

### Community 10 - "rep_counter.dart"
Cohesion: 0.05
Nodes (37): ../entities/body_pose.dart, joint_angle.dart, BodyJoint, acos, cosAngle, distal, dot, jointAngleDegrees (+29 more)

### Community 11 - "package:flutter/material.dart"
Cohesion: 0.06
Nodes (30): ColorScheme, buildScrollbar, NoScrollbarBehavior, build, EmptyState, scheme, theme, build (+22 more)

### Community 12 - "StatelessWidget"
Cohesion: 0.07
Nodes (36): ../../domain/usecases/watch_owned_area.dart, AppleGlassContainer, ExpressiveFlower, ExpressiveSwitch, ProfileAvatarButton, StatTile, _AchievementsRow, _NextAlarmCard (+28 more)

### Community 13 - "home_page.dart"
Cohesion: 0.06
Nodes (34): ../../../alarm/presentation/bloc/alarm_cubit.dart, ../../../alarm/presentation/bloc/alarm_state.dart, ../bloc/home_cubit.dart, ../bloc/home_state.dart, HomeCubit, activity, _animation, build (+26 more)

### Community 14 - "core/usecase/usecase.dart"
Cohesion: 0.08
Nodes (26): core/usecase/usecase.dart, AlarmRepository, call, _repository, call, _repository, call, _repository (+18 more)

### Community 15 - "territory_repository.dart"
Cohesion: 0.07
Nodes (28): ../entities/bounty_zone.dart, ../entities/geo_bounds.dart, ../entities/rival.dart, ../entities/territory_at_risk.dart, ../entities/territory.dart, TerritoryRepositoryImpl, fetchActiveBountyZones, fetchCurrentRival (+20 more)

### Community 16 - "semantic_colors.dart"
Cohesion: 0.06
Nodes (33): @immutable, AppSemanticColors get, BuildContext, AppSemanticColors, AppSemanticColorsX, bountyGold, bountyGoldContainer, copyWith (+25 more)

### Community 17 - "alarm_repository_impl.dart"
Cohesion: 0.06
Nodes (33): ../../../../core/error/failures.dart, ../datasources/alarm_local_datasource.dart, ../datasources/wake_up_tax_store.dart, ../../domain/repositories/alarm_repository.dart, cancelAlarm, cancelAllAlarms, completeWorkout, _computeStreak (+25 more)

### Community 18 - "run_tracking_repository_impl.dart"
Cohesion: 0.06
Nodes (33): ../datasources/location_provider_factory.dart, ../datasources/run_foreground_service.dart, ../datasources/run_progress_remote_datasource.dart, DeadReckoningProvider?, abandonRun, _beginTracking, captureRun, _checkpointInterval (+25 more)

### Community 19 - "Mock"
Cohesion: 0.09
Nodes (33): @LazySingleton, GoTrueClient, SystemCapabilities, AlarmLocalDataSource, WatchCurrentStreak, AuthRemoteDataSource, WatchMySquad, RunForegroundService (+25 more)

### Community 20 - "onboarding_page.dart"
Cohesion: 0.06
Nodes (32): battery_exemption_page.dart, _backToMarketing, _backToNotificationRationale, body, build, _cardIndex, _cards, _continueFromNotificationRationale (+24 more)

### Community 21 - "auth_dialog.dart"
Cohesion: 0.06
Nodes (32): ../../../../core/theme/google_logo.dart, ../../domain/usecases/link_with_email.dart, ../../domain/usecases/link_with_google.dart, ../../domain/usecases/send_password_reset_email.dart, ../../domain/usecases/sign_in_with_google.dart, ../../domain/usecases/sign_in_with_password.dart, FormState, AuthDialogMode (+24 more)

### Community 22 - "squad_repository_impl.dart"
Cohesion: 0.06
Nodes (32): ../datasources/squad_remote_datasource.dart, ../../domain/entities/streak_tier.dart, broadcastTelemetry, _cachedSquad, createSquad, _currentUserId, _emitSquad, _fetchedOnce (+24 more)

### Community 23 - "alarm_cubit.dart"
Cohesion: 0.06
Nodes (29): alarm_state.dart, ../../domain/usecases/cancel_alarm.dart, ../../domain/usecases/complete_alarm_workout.dart, ../../domain/usecases/dismiss_alarm.dart, ../../domain/usecases/schedule_alarm.dart, ../../domain/usecases/set_alarm_active.dart, ../../domain/usecases/watch_alarms.dart, ../../domain/usecases/watch_current_tax_multiplier.dart (+21 more)

### Community 24 - "alarm_ring_page.dart"
Cohesion: 0.07
Nodes (30): Animation, alarm, AlarmRingPage, _AlarmRingPageState, _clock, _controller, createState, didChangeDependencies (+22 more)

### Community 25 - "@injectable"
Cohesion: 0.12
Nodes (31): @injectable, UseCase, CancelAlarm, CancelAllAlarms, CompleteAlarmWorkout, DismissAlarm, EngageAlarmLockdown, RearmAlarmsFromCache (+23 more)

### Community 26 - "home_cubit_test.dart"
Cohesion: 0.07
Nodes (29): _MockPullDownSync, _MockWatchCurrentStreak, _MockWatchMySquad, _MockWatchOwnedArea, package:awaken/features/alarm/domain/usecases/watch_current_streak.dart, package:awaken/features/home/domain/usecases/watch_recent_activity.dart, package:awaken/features/profile/presentation/bloc/profile_cubit.dart, package:awaken/features/profile/presentation/bloc/profile_state.dart (+21 more)

### Community 27 - "leaderboards_sheet.dart"
Cohesion: 0.07
Nodes (29): ../../domain/usecases/get_global_leaderboard.dart, ../../domain/usecases/get_nearby_leaderboard.dart, build, createState, dispose, _entries, _error, _fetch (+21 more)

### Community 28 - "map_style_loader.dart"
Cohesion: 0.07
Nodes (29): double get, Key, _advance, _armTimeout, _bundledFallbackAssetPath, bundledFallbackMaxZoom, _bundledFallbackPlaceholder, dataMaxZoom (+21 more)

### Community 29 - "run_tracking_repository.dart"
Cohesion: 0.08
Nodes (23): class, ../entities/run_capture_result.dart, ../entities/run_track_state.dart, Exception, AuthDataSourceException, RunTrackingRepositoryImpl, abandonRun, captureRun (+15 more)

### Community 30 - "battery_exemption_page.dart"
Cohesion: 0.07
Nodes (28): ../../domain/entities/battery_exemption_status.dart, ../../domain/usecases/check_battery_exemption_status.dart, ../../domain/usecases/open_oem_autostart_settings.dart, ../../domain/usecases/request_battery_exemption.dart, actionLabel, bg, build, busy (+20 more)

### Community 31 - "AppDatabase"
Cohesion: 0.09
Nodes (24): @DriftDatabase, AppDatabase, package:awaken/features/alarm/data/datasources/wake_up_tax_store.dart, package:awaken/features/home/data/repositories/home_activity_repository_impl.dart, package:awaken/features/home/domain/entities/recent_activity_entry.dart, package:awaken/sync/local/database.dart, package:awaken/sync/outbox/local_writer.dart, package:awaken/sync/outbox/outbox_operation.dart (+16 more)

### Community 32 - "home_page_test.dart"
Cohesion: 0.09
Nodes (26): _FakeAlarmCubit, WatchCurrentUser, package:awaken/core/di/injection.dart, package:awaken/core/theme/app_theme.dart, package:awaken/features/alarm/presentation/bloc/alarm_cubit.dart, package:awaken/features/alarm/presentation/bloc/alarm_state.dart, package:awaken/features/alarm/presentation/pages/alarm_list_page.dart, package:awaken/features/home/presentation/bloc/home_cubit.dart (+18 more)

### Community 33 - "run_tracking_repository_impl_test.dart"
Cohesion: 0.07
Nodes (26): class _MockLocationProviderFactory extends, class _MockRunProgressRemoteDataSource extends, package:awaken/features/territory/data/datasources/location_provider_factory.dart, package:awaken/features/territory/data/datasources/run_foreground_service.dart, package:awaken/features/territory/data/datasources/run_progress_remote_datasource.dart, package:awaken/features/territory/data/repositories/run_tracking_repository_impl.dart, package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart, _controller (+18 more)

### Community 34 - "alarm_repository.dart"
Cohesion: 0.07
Nodes (23): ../entities/alarm_schedule.dart, cancelAlarm, cancelAllAlarms, completeWorkout, dismissAlarm, engageRingLockdown, rearmFromCache, reconcileRecurringAlarms (+15 more)

### Community 35 - "squad_remote_datasource.dart"
Cohesion: 0.07
Nodes (26): _awaitSubscribed, _broadcastEvent, broadcastTelemetry, _channelFor, _channelRefCounts, _channels, closeAllChannels, createSquad (+18 more)

### Community 36 - "squad_loaded_view.dart"
Cohesion: 0.08
Nodes (23): conquest_ticker.dart, invite_code_card.dart, leaderboard_row.dart, build, build, build, SquadState, build (+15 more)

### Community 37 - "app_shell_page.dart"
Cohesion: 0.08
Nodes (23): ../../../alarm/presentation/pages/alarm_list_page.dart, @visibleForTesting, ../../../home/presentation/pages/home_page.dart, AdaptiveNavScaffold, body, build, createState, _destinations (+15 more)

### Community 38 - "sync_worker.dart"
Cohesion: 0.08
Nodes (24): ../connectivity/connectivity_watcher.dart, _applyFailure, _backoffDelay, _classifyError, _connectivity, _connectivitySub, _db, dispose (+16 more)

### Community 39 - "home_cubit.dart"
Cohesion: 0.08
Nodes (23): ../../../alarm/data/datasources/wake_up_tax_store.dart, ../../domain/usecases/watch_recent_activity.dart, home_state.dart, _activitySub, _areaSub, close, _pullDownSync, _rankSub (+15 more)

### Community 40 - "profile_page.dart"
Cohesion: 0.10
Nodes (23): ../../../alarm/presentation/pages/alarm_reliability_test_page.dart, ../bloc/profile_cubit.dart, ../bloc/profile_state.dart, core/theme/theme_mode_cubit.dart, Cubit, AwakenApp, ThemeModeCubit, ProfileCubit (+15 more)

### Community 41 - "alarm_list_page.dart"
Cohesion: 0.10
Nodes (23): alarm_reliability_test_page.dart, alarm_ring_page.dart, ../bloc/alarm_cubit.dart, ../bloc/alarm_state.dart, AlarmCubit, AlarmListPage, _AlarmListPageState, _confirmDelete (+15 more)

### Community 42 - "pose_mapper.dart"
Cohesion: 0.09
Nodes (22): dart:typed_data, dart:ui, builder, bytes, cameraImageToInputImage, deviceOrientationDegrees, format, fromBytes (+14 more)

### Community 43 - "squad_cubit.dart"
Cohesion: 0.08
Nodes (23): ../../domain/repositories/squad_repository.dart, ../../domain/usecases/create_squad.dart, ../../domain/usecases/join_squad.dart, ../../domain/usecases/leave_squad.dart, ../../domain/usecases/watch_leaderboard.dart, ../../domain/usecases/watch_my_squad.dart, ../../domain/usecases/watch_squad_presence.dart, close (+15 more)

### Community 44 - "squad_cubit_test.dart"
Cohesion: 0.08
Nodes (23): package:awaken/core/usecase/usecase.dart, package:awaken/features/squad/domain/entities/leaderboard_entry.dart, package:awaken/features/squad/domain/entities/squad_presence_member.dart, package:awaken/features/squad/domain/entities/streak_tier.dart, package:awaken/features/squad/domain/usecases/create_squad.dart, package:awaken/features/squad/domain/usecases/join_squad.dart, package:awaken/features/squad/domain/usecases/leave_squad.dart, package:awaken/features/squad/domain/usecases/watch_leaderboard.dart (+15 more)

### Community 45 - "alarm_card.dart"
Cohesion: 0.09
Nodes (21): alarm_chip.dart, BorderRadius, alarm, AlarmCard, build, on, onDelete, onTap (+13 more)

### Community 46 - "auth_repository_impl.dart"
Cohesion: 0.09
Nodes (22): ../../../alarm/domain/repositories/alarm_repository.dart, ../datasources/auth_remote_datasource.dart, ../../domain/repositories/auth_repository.dart, _alarmRepository, _clearIdentityState, _db, deleteAccount, ensureSession (+14 more)

### Community 47 - "alarm_repository_impl_test.dart"
Cohesion: 0.09
Nodes (21): AlarmSettings, Fake, _MockLocalWriter, _MockSystemCapabilities, _MockWakeUpTaxStore, package:awaken/core/platform/system_capabilities.dart, package:awaken/features/alarm/data/datasources/alarm_local_datasource.dart, package:awaken/features/alarm/data/repositories/alarm_repository_impl.dart (+13 more)

### Community 48 - "AppDelegate.swift"
Cohesion: 0.09
Nodes (17): Any, Flutter, flutter_foreground_task, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterPluginRegistry, FlutterSceneDelegate (+9 more)

### Community 49 - "territory_repository_impl.dart"
Cohesion: 0.09
Nodes (22): ../datasources/territory_remote_datasource.dart, ../../domain/entities/bounty_zone.dart, ../../domain/entities/rival.dart, ../../domain/entities/territory_at_risk.dart, ../../domain/repositories/territory_repository.dart, _cacheCap, _currentUserId, _db (+14 more)

### Community 50 - "schedule_sheet.dart"
Cohesion: 0.09
Nodes (21): DateTime get, ios_day_toggle.dart, ios_mode_pill.dart, ios_step_button.dart, build, createState, _days, _formatTargetSummary (+13 more)

### Community 51 - "run_track_state.dart"
Cohesion: 0.09
Nodes (22): gps_quality.dart, copyWith, _degToRad, distanceMeters, dLat, dLon, earthRadiusM, elapsed (+14 more)

### Community 52 - "VoidCallback"
Cohesion: 0.09
Nodes (19): build, IosDayToggle, label, onTap, selected, tooltip, build, IosModePill (+11 more)

### Community 53 - "auth_repository.dart"
Cohesion: 0.09
Nodes (20): AppUser? get, init, ringing, scheduled, stop, stopAll, currentUser, deleteAccount (+12 more)

### Community 54 - "auth_remote_datasource.dart"
Cohesion: 0.09
Nodes (21): core/config/env.dart, _client, currentUser, deleteAccount, _googleSignInInitialized, linkWithEmail, linkWithGoogle, message (+13 more)

### Community 55 - "app.dart"
Cohesion: 0.09
Nodes (21): core/router/navigator_key.dart, core/theme/app_theme.dart, core/theme/no_scrollbar_behavior.dart, features/alarm/domain/usecases/engage_alarm_lockdown.dart, features/alarm/domain/usecases/release_alarm_lockdown.dart, features/alarm/presentation/bloc/alarm_cubit.dart, features/alarm/presentation/bloc/alarm_state.dart, features/alarm/presentation/pages/alarm_ring_page.dart (+13 more)

### Community 56 - "../../../../core/theme/expressive_widgets.dart"
Cohesion: 0.10
Nodes (19): ../../../../core/theme/expressive_widgets.dart, ../../../../core/theme/gamification_widgets.dart, ../../domain/entities/leaderboard_entry.dart, int get, build, count, index, isTied (+11 more)

### Community 57 - "app_constants.dart"
Cohesion: 0.09
Nodes (21): AppConstants, bronzeStreakTierThreshold, calibrationRepCount, goldStreakTierThreshold, loopClosureRadiusMeters, maxSustainedSpeedMetersPerSecond, minRunLengthMeters, penaltyMultiplierCap (+13 more)

### Community 58 - "Color"
Cohesion: 0.10
Nodes (18): Color, IconData, AlarmChip, bg, build, fg, icon, label (+10 more)

### Community 59 - "pose_verification_repository_impl.dart"
Cohesion: 0.10
Nodes (20): ../datasources/camera_datasource.dart, ../datasources/pose_detector_datasource.dart, ../../domain/repositories/pose_verification_repository.dart, ../../domain/services/rep_counter.dart, _camera, _emit, _generation, _handleUsablePose (+12 more)

### Community 60 - "State"
Cohesion: 0.14
Nodes (21): _AlarmRingOverlay, _AlarmRingOverlayState, _StartupFlow, _StartupFlowState, _GreetingText, _GreetingTextState, _Pulsing, _PulsingState (+13 more)

### Community 61 - "verification_cubit.dart"
Cohesion: 0.10
Nodes (19): ../../domain/entities/verification_state.dart, ../../domain/usecases/start_verification_session.dart, ../../domain/usecases/stop_verification_session.dart, ../../domain/usecases/watch_verification_state.dart, begin, close, _lastExercise, _lastTargetReps (+11 more)

### Community 62 - "home_state.dart"
Cohesion: 0.10
Nodes (19): copyWith, HomeState, ownedAreaError, ownedAreaLoading, ownedAreaSqm, props, recentActivity, recentActivityError (+11 more)

### Community 63 - "auth_dialog_test.dart"
Cohesion: 0.13
Nodes (19): LinkWithEmail, LinkWithGoogle, SendPasswordResetEmail, SignInWithGoogle, SignInWithPassword, package:awaken/features/profile/domain/usecases/link_with_email.dart, package:awaken/features/profile/domain/usecases/link_with_google.dart, package:awaken/features/profile/domain/usecases/send_password_reset_email.dart (+11 more)

### Community 64 - "auth_repository_impl_test.dart"
Cohesion: 0.10
Nodes (19): _MockSquadRepository, _MockSyncWorker, package:awaken/features/alarm/domain/repositories/alarm_repository.dart, package:awaken/features/profile/data/datasources/auth_remote_datasource.dart, package:awaken/features/profile/data/repositories/auth_repository_impl.dart, package:awaken/features/squad/domain/repositories/squad_repository.dart, package:awaken/sync/outbox/sync_worker.dart, package:awaken/sync/pull/pull_down_sync.dart (+11 more)

### Community 65 - "workout_celebration_sheet.dart"
Cohesion: 0.11
Nodes (17): core/di/injection.dart, ../../domain/usecases/watch_current_streak.dart, ../../domain/usecases/watch_current_user.dart, alarm, bg, build, _exerciseNoun, fg (+9 more)

### Community 66 - "conquest_ticker.dart"
Cohesion: 0.11
Nodes (18): ../../../../core/theme/motion_tokens.dart, ../../../../core/theme/shape_tokens.dart, ../../domain/entities/territory_capture_feed_item.dart, ../../domain/usecases/get_recent_territory_captures.dart, build, ConquestTicker, ConquestTickerState, createState (+10 more)

### Community 67 - "onboarding_repository_impl.dart"
Cohesion: 0.11
Nodes (15): ../datasources/onboarding_local_datasource.dart, ../../domain/repositories/onboarding_repository.dart, OnboardingLocalDataSource, hasSeenOnboarding, _local, markOnboardingSeen, OnboardingRepositoryImpl, hasSeenOnboarding (+7 more)

### Community 68 - "run_tracking_cubit.dart"
Cohesion: 0.11
Nodes (18): ../../domain/entities/run_capture_result.dart, ../../domain/entities/run_track_state.dart, ../../domain/usecases/abandon_run.dart, ../../domain/usecases/capture_run.dart, ../../domain/usecases/start_run.dart, ../../domain/usecases/watch_run_state.dart, abandon, _abandonRun (+10 more)

### Community 69 - "check_battery_exemption_status.dart"
Cohesion: 0.12
Nodes (15): ../entities/battery_exemption_status.dart, BatteryExemptionRepositoryImpl, BatteryExemptionRepository, getManufacturer, isAggressiveOem, isIgnoringBatteryOptimizations, openOemAutostartSettings, requestIgnoreBatteryOptimizations (+7 more)

### Community 70 - "DataClass"
Cohesion: 0.19
Nodes (19): AlarmRow, AlarmsCompanion, DataClass, OutboxEntryRow, RunCheckpointRow, RunCheckpointsCompanion, RunRow, RunsCompanion (+11 more)

### Community 71 - "main_common.dart"
Cohesion: 0.11
Nodes (17): app.dart, features/alarm/data/datasources/alarm_local_datasource.dart, features/alarm/domain/usecases/rearm_alarms_from_cache.dart, features/alarm/domain/usecases/reconcile_recurring_alarms.dart, features/profile/domain/usecases/ensure_auth_session.dart, features/profile/domain/usecases/refresh_auth_session.dart, features/territory/data/datasources/location_provider_factory.dart, bootstrap (+9 more)

### Community 72 - "String?"
Cohesion: 0.11
Nodes (16): ../../domain/entities/app_user.dart, AppUser, avatarUrl, displayName, email, id, isAnonymous, props (+8 more)

### Community 73 - "alarm_reliability_test_page.dart"
Cohesion: 0.12
Nodes (17): AlarmReliabilityTestPage, _AlarmReliabilityTestPageState, createState, _cubit, dispose, _measuredDelay, _phase, _scheduledFor (+9 more)

### Community 74 - "squad_repository_impl_test.dart"
Cohesion: 0.12
Nodes (16): class _MockSquadRemoteDataSource extends, CurrentState, SquadRemoteDataSource, _MockGoTrueClient, package:awaken/features/squad/data/datasources/squad_remote_datasource.dart, package:awaken/features/squad/data/repositories/squad_repository_impl.dart, package:awaken/features/squad/domain/entities/squad.dart, auth (+8 more)

### Community 75 - "territory_repository_impl_test.dart"
Cohesion: 0.12
Nodes (16): class _MockTerritoryRemoteDataSource extends, _MockSupabaseClient, package:awaken/features/territory/data/datasources/territory_remote_datasource.dart, package:awaken/features/territory/data/repositories/territory_repository_impl.dart, _MockUser, auth, db, insertRows (+8 more)

### Community 76 - "territories_table.dart"
Cohesion: 0.13
Nodes (15): IntColumn get, areaSqm, deletedAt, geoJson, health, id, ownerId, primaryKey (+7 more)

### Community 77 - "shape_tokens.dart"
Cohesion: 0.12
Nodes (15): navigatorKey, extraExtraLarge, extraLarge, extraLargeExtra, large, largeExtra, medium, mediumLarge (+7 more)

### Community 78 - "List"
Cohesion: 0.10
Nodes (18): call, props, BatteryExemptionStatus, isAggressiveOem, isExempt, manufacturer, props, id (+10 more)

### Community 79 - "squad_repository.dart"
Cohesion: 0.12
Nodes (16): broadcastTelemetry, createSquad, fetchGlobalLeaderboard, fetchMyGlobalRank, fetchMyNearbyRank, fetchMySquadRank, fetchNearbyLeaderboard, fetchRecentTerritoryCaptures (+8 more)

### Community 80 - "text_prompt_dialog.dart"
Cohesion: 0.12
Nodes (16): build, _controller, createState, dispose, _error, hintText, maxLines, _submit (+8 more)

### Community 81 - "runs_table.dart"
Cohesion: 0.12
Nodes (16): areaSqm, bonusAreaSqm, bountyMultiplier, capturedAreaSqm, deletedAt, endedAt, id, integrityVerdict (+8 more)

### Community 82 - "rep_counter_test.dart"
Cohesion: 0.12
Nodes (16): package:awaken/features/verification/domain/entities/body_pose.dart, package:awaken/features/verification/domain/services/joint_angle.dart, package:awaken/features/verification/domain/services/rep_counter.dart, required double rightKneeAngleHint,
  double, return, _feed, _feed2, knee (+8 more)

### Community 83 - "../../../alarm/domain/entities/alarm_schedule.dart"
Cohesion: 0.14
Nodes (13): ../../../alarm/domain/entities/alarm_schedule.dart, ../entities/verification_state.dart, PoseVerificationRepositoryImpl, PoseVerificationRepository, start, stop, watchState, call (+5 more)

### Community 84 - "verification_state.dart"
Cohesion: 0.13
Nodes (15): body_pose.dart, calibrationRepsRemaining, completedReps, copyWith, currentPose, exerciseMode, isActiveCameraSession, isComplete (+7 more)

### Community 85 - "compilerOptions"
Cohesion: 0.12
Nodes (16): compilerOptions, allowJs, allowSyntheticDefaultImports, checkJs, forceConsistentCasingInFileNames, isolatedModules, lib, module (+8 more)

### Community 86 - "motion_tokens.dart"
Cohesion: 0.12
Nodes (15): defaultSpatial, effectsCurve, expressiveDefaultSpatial, expressiveFastEffects, expressiveFastSpatial, fastEffects, fastSpatial, MotionTokens (+7 more)

### Community 87 - "scripted_location_provider.dart"
Cohesion: 0.12
Nodes (15): GeolocatorLocationProvider, assetPath, _controller, create, dispose, getCurrentPosition, positions, ScriptedLocationProvider (+7 more)

### Community 88 - "MainActivity"
Cohesion: 0.21
Nodes (4): MainActivity, Bundle, FlutterActivity, FlutterEngine

### Community 89 - "gamification_widgets.dart"
Cohesion: 0.13
Nodes (14): ../constants/app_constants.dart, ../../features/squad/domain/entities/streak_tier.dart, build, child, multiplier, _ringColor, ringWidth, size (+6 more)

### Community 90 - "DateTime"
Cohesion: 0.13
Nodes (13): DateTime, kind, occurredAt, props, RecentActivityEntry, RecentActivityKind, text, areaSqm (+5 more)

### Community 91 - "package:drift/drift.dart"
Cohesion: 0.15
Nodes (13): DateTimeColumn get, distanceMeters, id, pointsJson, primaryKey, runId, startedAt, updatedAt (+5 more)

### Community 92 - "squad_presence_member.dart"
Cohesion: 0.13
Nodes (13): double?, activity, avatarUrl, displayName, lat, lng, props, SquadPresenceMember (+5 more)

### Community 93 - "../repositories/squad_repository.dart"
Cohesion: 0.13
Nodes (11): ../entities/squad_presence_member.dart, call, GetMyLeaderboardRank, _repository, call, _repository, call, _repository (+3 more)

### Community 94 - "app_theme.dart"
Cohesion: 0.13
Nodes (14): AppTheme, _build, dark, darkBorderOutline, darkCanvas, darkCardContainer, darkCardContainerHigh, darkSurface (+6 more)

### Community 95 - "sync_outbox_table.dart"
Cohesion: 0.14
Nodes (13): @TableIndex, attemptCount, createdAt, entityId, entityTable, errorType, id, lastError (+5 more)

### Community 96 - "edit_name_dialog.dart"
Cohesion: 0.15
Nodes (13): ../auth_error_message.dart, ../../domain/usecases/update_display_name.dart, build, _controller, createState, currentName, dispose, EditNameDialog (+5 more)

### Community 97 - "battery_exemption_repository_impl.dart"
Cohesion: 0.14
Nodes (12): ../../../../core/platform/system_capabilities.dart, dart:io, ../../domain/repositories/battery_exemption_repository.dart, _aggressiveOems, getManufacturer, isAggressiveOem, isIgnoringBatteryOptimizations, openOemAutostartSettings (+4 more)

### Community 98 - "map_style_overlays.dart"
Cohesion: 0.14
Nodes (12): ../../../../core/theme/semantic_colors.dart, ../../domain/entities/gps_quality.dart, build, GpsQualityChip, quality, bottom, build, MapDegradedModeChip (+4 more)

### Community 99 - "google_logo.dart"
Cohesion: 0.14
Nodes (13): CustomPainter, _blue, build, GoogleLogo, _GoogleLogoPainter, _green, paint, _red (+5 more)

### Community 100 - "alarm_state.dart"
Cohesion: 0.15
Nodes (13): ../../domain/entities/alarm_schedule.dart, AlarmSchedule, alarms, AlarmState, copyWith, currentTaxMultiplier, props, ringingAlarm (+5 more)

### Community 101 - "SquadRepository"
Cohesion: 0.16
Nodes (11): ../entities/squad.dart, SquadRepositoryImpl, SquadRepository, call, _repository, call, _repository, call (+3 more)

### Community 102 - "src/index.ts"
Cohesion: 0.22
Nodes (8): pmtiles_path(), tile_path(), CACHE, Env, fetch(), KeyNotFoundError, nativeDecompress(), R2Source

### Community 103 - "run_foreground_service.dart"
Cohesion: 0.15
Nodes (12): @pragma, _ensureInitialized, _initialized, onDestroy, onRepeatEvent, onStart, runTrackingTaskCallback, _RunTrackingTaskHandler (+4 more)

### Community 104 - "package:flutter_bloc/flutter_bloc.dart"
Cohesion: 0.17
Nodes (11): ../bloc/squad_cubit.dart, leaderboards_sheet.dart, build, SquadPage, build, SquadView, package:flutter_bloc/flutter_bloc.dart, ../../../profile/presentation/widgets/current_user_avatar_button.dart (+3 more)

### Community 105 - "SquadCubit"
Cohesion: 0.18
Nodes (12): ../bloc/squad_state.dart, SquadCubit, build, SquadBody, state, confirmLeaveSquad, showCreateSquadDialog, showJoinSquadDialog (+4 more)

### Community 106 - "alarm_schedule.dart"
Cohesion: 0.15
Nodes (12): bool get, copyWith, firstOccurrence, id, isActive, isRecurring, nextOccurrenceAfter, penaltyMultiplier (+4 more)

### Community 107 - "alarms_table.dart"
Cohesion: 0.15
Nodes (12): BoolColumn get, deletedAt, exerciseMode, id, isActive, nativeId, penaltyMultiplier, primaryKey (+4 more)

### Community 108 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.17
Nodes (9): dart:convert, package:awaken/core/theme/expressive_widgets.dart, package:awaken/features/alarm/domain/entities/alarm_schedule.dart, package:awaken/features/territory/data/mappers/territory_mapper.dart, package:flutter_test/flutter_test.dart, main, main, main (+1 more)

### Community 109 - "weekly_reset_ceremony_gate.dart"
Cohesion: 0.17
Nodes (12): ../../data/datasources/weekly_reset_local_datasource.dart, ../../domain/usecases/get_my_leaderboard_rank.dart, ../../domain/usecases/get_my_squad_rank.dart, build, _checked, child, createState, initState (+4 more)

### Community 110 - "account_actions_section.dart"
Cohesion: 0.17
Nodes (12): delete_account_dialog.dart, ../../domain/usecases/delete_account.dart, ../../domain/usecases/sign_out.dart, AccountActionsSection, _AccountActionsSectionState, build, createState, _deleteAccount (+4 more)

### Community 111 - "rise_in.dart"
Cohesion: 0.17
Nodes (12): Duration, build, child, createState, delay, dispose, initState, _played (+4 more)

### Community 112 - "watch_recent_activity.dart"
Cohesion: 0.17
Nodes (11): ../entities/recent_activity_entry.dart, IfReady, AlarmRepositoryImpl, HomeActivityRepositoryImpl, HomeActivityRepository, watchRecentActivity, call, _repository (+3 more)

### Community 113 - "static const"
Cohesion: 0.17
Nodes (11): hasSeenOnboarding, _hasSeenOnboardingKey, markOnboardingSeen, getLastKnownRank, getLastSeenWeek, _rankKey, save, _weekKey (+3 more)

### Community 114 - "home_activity_repository_impl.dart"
Cohesion: 0.17
Nodes (10): AppDatabase get, ../../domain/entities/recent_activity_entry.dart, ../../domain/repositories/home_activity_repository.dart, appDatabase, supabaseClient, _db, _exerciseLabel, watchRecentActivity (+2 more)

### Community 115 - "devDependencies"
Cohesion: 0.17
Nodes (12): @cloudflare/workers-types, devDependencies, @cloudflare/workers-types, tsx, @types/node, typescript, wrangler, types (+4 more)

### Community 116 - "squad_state.dart"
Cohesion: 0.17
Nodes (11): ../../domain/entities/squad.dart, ../../domain/entities/squad_presence_member.dart, copyWith, errorMessage, isLeavingSquad, leaderboard, presence, props (+3 more)

### Community 117 - "failures.dart"
Cohesion: 0.29
Nodes (11): AlarmOperationFailure, AuthFailure, Failure, LocalStorageFailure, message, NetworkFailure, PermissionFailure, props (+3 more)

### Community 118 - "wake_up_tax_store.dart"
Cohesion: 0.17
Nodes (11): bump, current, _db, _localWriter, reset, _rowId, WakeUpTaxStore, watch (+3 more)

### Community 119 - "territory_capture_feed_item.dart"
Cohesion: 0.18
Nodes (10): areaTakenSqm, captureId, createdAt, lat, lng, loserDisplayName, loserId, props (+2 more)

### Community 120 - "squad_page_shared.dart"
Cohesion: 0.17
Nodes (11): confirmed, created, cubit, isLeaderboardRowTied, joined, messenger, reported, showReportMemberDialog (+3 more)

### Community 121 - "profile_cubit.dart"
Cohesion: 0.18
Nodes (10): ../../../alarm/domain/usecases/watch_current_streak.dart, _areaSub, close, _streakSub, _userSub, _watchCurrentStreak, _watchCurrentUser, _watchOwnedArea (+2 more)

### Community 122 - "kalman_golden_trajectory_test.dart"
Cohesion: 0.18
Nodes (10): dart:math, GeoPosition, _controller, dispose, emit, main, positions, _ScriptedLocationProvider (+2 more)

### Community 123 - "geolocator_location_provider.dart"
Cohesion: 0.18
Nodes (10): ../../domain/repositories/run_tracking_repository.dart, _controller, dispose, _ensurePermission, _onPosition, _positionSub, start, stop (+2 more)

### Community 124 - "package.json"
Cohesion: 0.18
Nodes (10): dependencies, pmtiles, name, private, scripts, deploy, start, test (+2 more)

### Community 125 - "env.dart"
Cohesion: 0.18
Nodes (10): Env, googleOAuthClientId, load, mapStyleUrl, _require, sentryDsn, supabasePublishableKey, supabaseUrl (+2 more)

### Community 126 - "system_capabilities.dart"
Cohesion: 0.18
Nodes (10): canScheduleExactAlarms, canUseFullScreenIntent, _channel, getManufacturer, openExactAlarmSettings, openFullScreenIntentSettings, openOemAutostartSettings, startAlarmLockdown (+2 more)

### Community 127 - "leaderboard_entry.dart"
Cohesion: 0.18
Nodes (10): areaSqm, avatarUrl, displayName, isYou, LeaderboardEntry, props, rank, streakTier (+2 more)

### Community 128 - "run_capture_result.dart"
Cohesion: 0.18
Nodes (10): accepted, bonusAreaSqm, bountyMultiplier, capturedAreaSqm, closedLoop, pending, props, rejectedReason (+2 more)

### Community 129 - "pull_down_sync.dart"
Cohesion: 0.18
Nodes (10): _db, _maxUpdatedAt, _pullAlarms, _pullSessions, _pullUserStats, run, _saveWatermark, _supabase (+2 more)

### Community 130 - "pulsing_dot.dart"
Cohesion: 0.20
Nodes (9): AnimationController, build, color, _controller, createState, didChangeDependencies, dispose, initState (+1 more)

### Community 131 - "skeleton_painter.dart"
Cohesion: 0.20
Nodes (9): ../../domain/entities/body_pose.dart, _bonePaint, _bones, imageSize, _jointPaint, paint, pose, shouldRepaint (+1 more)

### Community 132 - "territory_remote_datasource.dart"
Cohesion: 0.20
Nodes (9): ../../domain/entities/geo_bounds.dart, fetchActiveBountyZones, fetchCurrentRival, fetchMyOwnedAreaSqm, fetchTerritoriesAtRisk, fetchTerritoriesInBbox, _supabase, TerritoryRemoteDataSource (+1 more)

### Community 133 - "Equatable"
Cohesion: 0.17
Nodes (12): Equatable, NoParams, TerritoryCaptureFeedItem, BodyPose, JointPosition, joints, likelihood, props (+4 more)

### Community 134 - "location_provider_factory.dart"
Cohesion: 0.22
Nodes (9): geolocator_location_provider.dart, create, GeolocatorLocationProviderFactory, getCurrentPosition, LocationProviderFactory, ScriptedLocationProviderFactory, package:geolocator/geolocator.dart, package:kalman_dr/kalman_dr.dart (+1 more)

### Community 135 - "territory.dart"
Cohesion: 0.20
Nodes (9): int?, areaSqm, health, id, isMine, ownerId, polygons, props (+1 more)

### Community 136 - "alarm_payload.dart"
Cohesion: 0.20
Nodes (9): AlarmPayload, deriveNativeId, exerciseMode, fromJson, id, penaltyMultiplier, recurringDays, requiredReps (+1 more)

### Community 137 - "complete_alarm_workout.dart"
Cohesion: 0.20
Nodes (9): alarm, call, CompleteAlarmWorkoutParams, isPreview, props, _repository, repsCompleted, startedAt (+1 more)

### Community 138 - "package:supabase_flutter/supabase_flutter.dart"
Cohesion: 0.20
Nodes (8): friendlyAuthErrorMessage, clearProgress, _supabase, upsertProgress, package:supabase_flutter/supabase_flutter.dart, SupabaseClient, _MockSupabaseClient, _MockSupabaseClient

### Community 139 - "delete_account_dialog.dart"
Cohesion: 0.22
Nodes (9): build, _controller, createState, DeleteAccountDialog, _DeleteAccountDialogState, displayName, dispose, initState (+1 more)

### Community 140 - "rival.dart"
Cohesion: 0.20
Nodes (9): areaTakenSqm, asWinner, occurredAt, props, Rival, rivalDisplayName, rivalId, territoryLat (+1 more)

### Community 141 - "sessions_table.dart"
Cohesion: 0.20
Nodes (9): alarmId, completedAt, deletedAt, exerciseMode, id, primaryKey, repsCompleted, startedAt (+1 more)

### Community 142 - "local_writer.dart"
Cohesion: 0.20
Nodes (9): _db, deleteAlarm, _enqueue, insertRun, insertSession, upsertAlarm, upsertUserStats, ../local/database.dart (+1 more)

### Community 143 - "Table"
Cohesion: 0.39
Nodes (9): @DataClassName, Alarms, RunCheckpoints, Runs, Sessions, SyncMeta, Territories, UserStats (+1 more)

### Community 144 - "camera_datasource.dart"
Cohesion: 0.22
Nodes (8): CameraController?, CameraController? get, CameraDataSource, _controller, _preferredFormat, startFrontCameraStream, stop, static final

### Community 145 - "path_simplifier.dart"
Cohesion: 0.22
Nodes (8): ../../domain/entities/track_point.dart, PathSimplifier, _perpendicularDistanceMeters, _rdp, simplify, toGeoJsonLineString, toGeoJsonMap, toTimestampsJson

### Community 146 - "settings_row.dart"
Cohesion: 0.22
Nodes (8): build, icon, isFirst, isLast, label, onTap, SettingsRow, package:flutter/cupertino.dart

### Community 147 - "get_nearby_leaderboard.dart"
Cohesion: 0.22
Nodes (8): call, GetNearbyLeaderboard, GetNearbyLeaderboardParams, offset, radiusM, _repository, rowLimit, timeWindow

### Community 148 - "track_point.dart"
Cohesion: 0.22
Nodes (8): accuracy, fromJson, latitude, longitude, props, timestamp, toJson, TrackPoint

### Community 149 - "../../core/constants/app_constants.dart"
Cohesion: 0.25
Nodes (7): ../../core/constants/app_constants.dart, fromValue, label, StreakTier, streakTierForDays, value, String get

### Community 150 - "get_global_leaderboard.dart"
Cohesion: 0.25
Nodes (6): ../entities/leaderboard_entry.dart, call, GetGlobalLeaderboard, _repository, call, _repository

### Community 151 - "main_e2e.dart"
Cohesion: 0.25
Nodes (5): features/territory/data/datasources/scripted_location_provider.dart, main, main, main, main_common.dart

### Community 152 - "connectivity_watcher.dart"
Cohesion: 0.25
Nodes (7): Future, async, _connectivity, ConnectivityWatcher, _isOnline, onlineChanges, package:connectivity_plus/connectivity_plus.dart

### Community 153 - "start_verification_session.dart"
Cohesion: 0.25
Nodes (7): ExerciseMode, call, exercise, props, _repository, StartVerificationParams, targetReps

### Community 154 - "bounty_zone.dart"
Cohesion: 0.25
Nodes (7): BountyZone, centerLat, centerLng, id, multiplier, props, radiusM

### Community 155 - "injection.dart"
Cohesion: 0.29
Nodes (6): @InjectableInit, GetIt, injection.config.dart, configureDependencies, getIt, package:get_it/get_it.dart

### Community 156 - "android_management_mcp_proxy.js"
Cohesion: 0.33
Nodes (6): fs, getAccessToken(), https, main(), path, { spawn }

### Community 157 - "expressive_fab.dart"
Cohesion: 0.33
Nodes (6): build, createState, ExpressiveFab, ExpressiveFabState, onPressed, _pressed

### Community 159 - "geo_bounds.dart"
Cohesion: 0.29
Nodes (6): GeoBounds, maxLat, maxLng, minLat, minLng, props

### Community 160 - "pose_detector_datasource.dart"
Cohesion: 0.29
Nodes (6): close, _detector, PoseDetectorDataSource, process, package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart, PoseDetector

### Community 161 - "dart:async"
Cohesion: 0.33
Nodes (5): dart:async, _key, _load, setThemeMode, _userSet

### Community 162 - "territory_mapper.dart"
Cohesion: 0.33
Nodes (5): ../../domain/entities/territory.dart, fromRow, polygonsFromMultiPolygonGeoJson, TerritoryMapper, package:latlong2/latlong.dart

### Community 163 - "get_recent_territory_captures.dart"
Cohesion: 0.40
Nodes (4): ../entities/territory_capture_feed_item.dart, call, GetRecentTerritoryCaptures, _repository

### Community 164 - "gps_quality.dart"
Cohesion: 0.40
Nodes (4): fromAccuracyMeters, GpsQuality, poor, none,
  good,
  degraded,

### Community 165 - "AppLocalizations"
Cohesion: 0.40
Nodes (5): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, of, LocalizationsDelegate

### Community 166 - "exclude"
Cohesion: 0.50
Nodes (3): exclude, node_modules, **/*.test.ts

### Community 167 - "get_my_squad_rank.dart"
Cohesion: 0.50
Nodes (3): call, GetMySquadRank, _repository

### Community 168 - "_TerritoryPageState"
Cohesion: 0.67
Nodes (3): AutomaticKeepAliveClientMixin, TerritoryPage, _TerritoryPageState

### Community 170 - "_RepCounterState"
Cohesion: 0.67
Nodes (3): AngleRepCounter, _RepCounterState, RepCounter

## Knowledge Gaps
- **2221 isolated node(s):** `{ spawn }`, `fs`, `https`, `path`, `generate_basemap.sh script` (+2216 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `_` to `territory_remote_datasource.dart`, `location_provider_factory.dart`, `package:injectable/injectable.dart`, `active_run_page.dart`, `verification_page.dart`, `package:supabase_flutter/supabase_flutter.dart`, `home_page.dart`, `core/usecase/usecase.dart`, `territory_repository.dart`, `camera_datasource.dart`, `Mock`, `get_nearby_leaderboard.dart`, `get_global_leaderboard.dart`, `alarm_cubit.dart`, `connectivity_watcher.dart`, `@injectable`, `injection.dart`, `run_tracking_repository.dart`, `AppDatabase`, `home_page_test.dart`, `pose_detector_datasource.dart`, `alarm_repository.dart`, `get_recent_territory_captures.dart`, `app_shell_page.dart`, `get_my_squad_rank.dart`, `profile_page.dart`, `alarm_list_page.dart`, `home_cubit.dart`, `CreateSquad`, `JoinSquad`, `WatchLeaderboard`, `WatchSquadPresence`, `RunProgressRemoteDataSource`, `app.dart`, `auth_dialog_test.dart`, `onboarding_repository_impl.dart`, `check_battery_exemption_status.dart`, `main_common.dart`, `squad_repository_impl_test.dart`, `rep_counter_test.dart`, `../../../alarm/domain/entities/alarm_schedule.dart`, `../repositories/squad_repository.dart`, `SquadRepository`, `SquadCubit`, `watch_recent_activity.dart`, `static const`, `home_activity_repository_impl.dart`, `wake_up_tax_store.dart`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `AppDatabase` to `database.dart`, `pull_down_sync.dart`, `run_tracking_repository_impl_test.dart`, `_`, `sync_worker.dart`, `territory_repository_impl_test.dart`, `auth_repository_impl.dart`, `local_writer.dart`, `alarm_repository_impl_test.dart`, `alarm_repository_impl.dart`, `home_activity_repository_impl.dart`, `run_tracking_repository_impl.dart`, `territory_repository_impl.dart`, `wake_up_tax_store.dart`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `SquadRepository` connect `SquadRepository` to `_`, `get_recent_territory_captures.dart`, `run_tracking_cubit.dart`, `get_my_squad_rank.dart`, `squad_cubit.dart`, `auth_repository_impl.dart`, `squad_repository.dart`, `get_nearby_leaderboard.dart`, `verification_cubit.dart`, `get_global_leaderboard.dart`, `../repositories/squad_repository.dart`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **What connects `{ spawn }`, `fs`, `https` to the rest of the system?**
  _2221 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `database.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.015151515151515152 - nodes in this community are weakly interconnected._
- **Should `territory_page.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.015625 - nodes in this community are weakly interconnected._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.020618556701030927 - nodes in this community are weakly interconnected._