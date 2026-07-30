import 'package:awaken/features/alarm/data/datasources/wake_up_tax_store.dart';
import 'package:awaken/features/alarm/domain/usecases/watch_current_streak.dart';
import 'package:awaken/features/home/domain/entities/recent_activity_entry.dart';
import 'package:awaken/features/home/domain/usecases/watch_recent_activity.dart';
import 'package:awaken/features/home/presentation/bloc/home_cubit.dart';
import 'package:awaken/features/home/presentation/bloc/home_state.dart';
import 'package:awaken/features/squad/domain/entities/squad.dart';
import 'package:awaken/features/squad/domain/usecases/watch_my_rank.dart';
import 'package:awaken/features/squad/domain/usecases/watch_my_squad.dart';
import 'package:awaken/features/territory/domain/usecases/watch_owned_area.dart';
import 'package:awaken/sync/pull/pull_down_sync.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchCurrentStreak extends Mock implements WatchCurrentStreak {}

class _MockWatchOwnedArea extends Mock implements WatchOwnedArea {}

class _MockWatchMyRank extends Mock implements WatchMyRank {}

class _MockWatchMySquad extends Mock implements WatchMySquad {}

class _MockWatchRecentActivity extends Mock implements WatchRecentActivity {}

class _MockWakeUpTaxStore extends Mock implements WakeUpTaxStore {}

class _MockPullDownSync extends Mock implements PullDownSync {}

void main() {
  late _MockWatchCurrentStreak watchCurrentStreak;
  late _MockWatchOwnedArea watchOwnedArea;
  late _MockWatchMyRank watchMyRank;
  late _MockWatchMySquad watchMySquad;
  late _MockWatchRecentActivity watchRecentActivity;
  late _MockWakeUpTaxStore wakeUpTaxStore;
  late _MockPullDownSync pullDownSync;

  const squad = Squad(
    id: 'squad-1',
    name: 'Runners',
    inviteCode: 'ABC123',
    ownerId: 'user-1',
  );

  final activity = RecentActivityEntry(
    kind: RecentActivityKind.alarmDismissed,
    text: 'Dismissed alarm — 10 squats',
    occurredAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    watchCurrentStreak = _MockWatchCurrentStreak();
    watchOwnedArea = _MockWatchOwnedArea();
    watchMyRank = _MockWatchMyRank();
    watchMySquad = _MockWatchMySquad();
    watchRecentActivity = _MockWatchRecentActivity();
    wakeUpTaxStore = _MockWakeUpTaxStore();
    pullDownSync = _MockPullDownSync();

    when(() => wakeUpTaxStore.watch()).thenAnswer((_) => const Stream.empty());
  });

  HomeCubit buildCubit() => HomeCubit(
    watchCurrentStreak,
    watchOwnedArea,
    watchMyRank,
    watchMySquad,
    watchRecentActivity,
    wakeUpTaxStore,
    pullDownSync,
  );

  blocTest<HomeCubit, HomeState>(
    'each stream clears its own *Loading flag independently on first value',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => Stream.value(7));
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(() => watchMyRank()).thenAnswer((_) => const Stream.empty());
      when(() => watchMySquad()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchRecentActivity(),
      ).thenAnswer((_) => const Stream.empty());
    },
    build: buildCubit,
    expect: () => [
      isA<HomeState>()
          .having((s) => s.streak, 'streak', 7)
          .having((s) => s.streakLoading, 'streakLoading', false),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'a null squad rank clears squadRank rather than leaving a stale value',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => const Stream.empty());
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchMyRank(),
      ).thenAnswer((_) => Stream.fromIterable([5, null]));
      when(() => watchMySquad()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchRecentActivity(),
      ).thenAnswer((_) => const Stream.empty());
    },
    build: buildCubit,
    expect: () => [
      isA<HomeState>().having((s) => s.squadRank, 'squadRank', 5),
      isA<HomeState>().having((s) => s.squadRank, 'squadRank', isNull),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'a null squad clears squad rather than leaving a stale value',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => const Stream.empty());
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(() => watchMyRank()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchMySquad(),
      ).thenAnswer((_) => Stream.fromIterable([squad, null]));
      when(
        () => watchRecentActivity(),
      ).thenAnswer((_) => const Stream.empty());
    },
    build: buildCubit,
    expect: () => [
      isA<HomeState>().having((s) => s.squad, 'squad', squad),
      isA<HomeState>().having((s) => s.squad, 'squad', isNull),
    ],
  );

  blocTest<HomeCubit, HomeState>(
    'a failed recent-activity stream sets recentActivityError and clears '
    'recentActivityLoading',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => const Stream.empty());
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(() => watchMyRank()).thenAnswer((_) => const Stream.empty());
      when(() => watchMySquad()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchRecentActivity(),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
    },
    build: buildCubit,
    expect: () => [
      isA<HomeState>()
          .having((s) => s.recentActivityError, 'recentActivityError', true)
          .having(
            (s) => s.recentActivityLoading,
            'recentActivityLoading',
            false,
          ),
    ],
  );

  group('retryRecentActivity', () {
    blocTest<HomeCubit, HomeState>(
      'cancels the old subscription and re-subscribes, clearing the error',
      setUp: () {
        when(
          () => watchCurrentStreak(),
        ).thenAnswer((_) => const Stream.empty());
        when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
        when(() => watchMyRank()).thenAnswer((_) => const Stream.empty());
        when(() => watchMySquad()).thenAnswer((_) => const Stream.empty());
        when(
          () => watchRecentActivity(),
        ).thenAnswer((_) => Stream.error(Exception('first failure')));
      },
      build: buildCubit,
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => watchRecentActivity(),
        ).thenAnswer((_) => Stream.value([activity]));
        cubit.retryRecentActivity();
      },
      expect: () => [
        isA<HomeState>().having(
          (s) => s.recentActivityError,
          'recentActivityError',
          true,
        ),
        isA<HomeState>()
            .having(
              (s) => s.recentActivityError,
              'recentActivityError',
              false,
            )
            .having(
              (s) => s.recentActivityLoading,
              'recentActivityLoading',
              true,
            ),
        isA<HomeState>().having(
          (s) => s.recentActivity,
          'recentActivity',
          [activity],
        ),
      ],
    );
  });

  group('refresh', () {
    blocTest<HomeCubit, HomeState>(
      'delegates to PullDownSync.run()',
      setUp: () {
        when(
          () => watchCurrentStreak(),
        ).thenAnswer((_) => const Stream.empty());
        when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
        when(() => watchMyRank()).thenAnswer((_) => const Stream.empty());
        when(() => watchMySquad()).thenAnswer((_) => const Stream.empty());
        when(
          () => watchRecentActivity(),
        ).thenAnswer((_) => const Stream.empty());
        when(() => pullDownSync.run()).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.refresh(),
      expect: () => [],
      verify: (_) => verify(() => pullDownSync.run()).called(1),
    );
  });
}
