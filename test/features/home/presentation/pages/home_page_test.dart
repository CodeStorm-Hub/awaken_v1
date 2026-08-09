import 'dart:async';

import 'package:awaken/core/di/injection.dart';
import 'package:awaken/core/theme/app_theme.dart';
import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_cubit.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_state.dart';
import 'package:awaken/features/home/presentation/bloc/home_cubit.dart';
import 'package:awaken/features/home/presentation/bloc/home_state.dart';
import 'package:awaken/features/home/presentation/pages/home_page.dart';
import 'package:awaken/features/profile/domain/entities/app_user.dart';
import 'package:awaken/features/profile/domain/repositories/auth_repository.dart';
import 'package:awaken/features/profile/domain/usecases/watch_current_user.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeAlarmCubit extends MockCubit<AlarmState> implements AlarmCubit {}

class _FakeHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

class _FakeAuthRepository extends Mock implements AuthRepository {
  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get userChanges => const Stream.empty();
}

void main() {
  late _FakeAlarmCubit alarmCubit;
  late _FakeHomeCubit homeCubit;
  late StreamController<AlarmState> alarmStream;

  setUp(() {
    alarmCubit = _FakeAlarmCubit();
    homeCubit = _FakeHomeCubit();
    alarmStream = StreamController<AlarmState>.broadcast();

    when(() => homeCubit.state).thenReturn(const HomeState());
    whenListen(
      alarmCubit,
      alarmStream.stream,
      initialState: const AlarmState(),
    );

    // HomePage constructs its own HomeCubit via getIt internally (see
    // `home_page.dart`'s `BlocProvider<HomeCubit>(create: (_) => getIt<
    // HomeCubit>())`), so the fake has to be reachable through getIt rather
    // than injected via an ancestor BlocProvider like AlarmCubit is here.
    getIt.registerFactory<HomeCubit>(() => homeCubit);
    // CurrentUserAvatarButton (in HomePage's header) resolves this via getIt
    // — same fake used by alarm_list_page_test.dart to avoid needing the
    // app's full configureDependencies().
    final fakeAuthRepository = _FakeAuthRepository();
    getIt.registerFactory<WatchCurrentUser>(
      () => WatchCurrentUser(fakeAuthRepository),
    );
    // QuickActionsPill (HomePage's Territory/Squad shortcuts) resolves this
    // directly via getIt to gate guest access — see app_shell_page.dart's
    // identical pattern.
    getIt.registerFactory<AuthRepository>(() => fakeAuthRepository);
  });

  tearDown(() async {
    debugOnRebuildDirtyWidget = null;
    await alarmStream.close();
    await getIt.reset();
  });

  // `HomePage` reads `context.semanticColors` (the streak-flame chip) —
  // that's a `ThemeExtension` only `AppTheme.light`/`.dark` register, not
  // `MaterialApp`'s own default `ThemeData()`. Without it, `semanticColors`'
  // null-check throws the moment that chip builds.
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(null),
    home: BlocProvider<AlarmCubit>.value(value: alarmCubit, child: child),
  );

  testWidgets(
    'an AlarmCubit emission does not rebuild the HomeState-driven subtree '
    '(regression test for the BlocBuilder-nesting perf fix in home_page.dart)',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          HomePage(
            onOpenAlarms: () {},
            onOpenTerritory: () {},
            onOpenSquad: () {},
          ),
        ),
      );
      await tester.pump();

      // `debugOnRebuildDirtyWidget` is a documented Flutter Widget Inspector
      // hook: the framework calls it for every element it rebuilds. Used
      // here instead of instrumenting `AchievementsRow`/`RecentActivitySection`
      // directly, since they now live in their own widget files (extracted
      // from home_page.dart) and this test cares about *whether* they
      // rebuild, not about importing and wiring them up individually.
      final rebuiltTypeNames = <String>{};
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        rebuiltTypeNames.add(element.widget.runtimeType.toString());
      };

      alarmStream.add(
        AlarmState(
          alarms: [
            AlarmSchedule(
              id: 'a',
              scheduledTime: DateTime(2026, 1, 1, 7),
              exerciseMode: ExerciseMode.squat,
              requiredReps: 10,
            ),
          ],
        ),
      );
      // Two pumps: the first lets the broadcast stream's event propagate and
      // BlocBuilder call setState (marking itself dirty); the second draws
      // the frame that actually rebuilds it. A single pump can land in
      // between those two steps and see nothing dirty yet.
      await tester.pump();
      await tester.pump();

      debugOnRebuildDirtyWidget = null;

      // Sanity check that the update actually happened at all.
      expect(find.text('07:00'), findsOneWidget);
      expect(
        rebuiltTypeNames,
        contains('BlocBuilder<AlarmCubit, AlarmState>'),
        reason: 'sanity check: the alarm-scoped BlocBuilder should rebuild',
      );

      expect(
        rebuiltTypeNames,
        isNot(contains('AchievementsRow')),
        reason:
            'AlarmCubit emission must not rebuild the HomeState-only subtree',
      );
      expect(rebuiltTypeNames, isNot(contains('RecentActivitySection')));
      // The HomeCubit-scoped BlocBuilder itself must not have rebuilt either
      // — if it had, its whole HomeState-driven subtree would be dirty too.
      expect(
        rebuiltTypeNames,
        isNot(contains('BlocBuilder<HomeCubit, HomeState>')),
      );
    },
  );
}
