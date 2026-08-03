import 'dart:async';

import 'package:awaken/core/usecase/usecase.dart';
import 'package:awaken/features/squad/domain/entities/leaderboard_entry.dart';
import 'package:awaken/features/squad/domain/entities/squad.dart';
import 'package:awaken/features/squad/domain/entities/squad_presence_member.dart';
import 'package:awaken/features/squad/domain/entities/streak_tier.dart';
import 'package:awaken/features/squad/domain/repositories/squad_repository.dart';
import 'package:awaken/features/squad/domain/usecases/create_squad.dart';
import 'package:awaken/features/squad/domain/usecases/join_squad.dart';
import 'package:awaken/features/squad/domain/usecases/leave_squad.dart';
import 'package:awaken/features/squad/domain/usecases/watch_leaderboard.dart';
import 'package:awaken/features/squad/domain/usecases/watch_my_squad.dart';
import 'package:awaken/features/squad/domain/usecases/watch_squad_presence.dart';
import 'package:awaken/features/squad/presentation/bloc/squad_cubit.dart';
import 'package:awaken/features/squad/presentation/bloc/squad_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchMySquad extends Mock implements WatchMySquad {}

class _MockCreateSquad extends Mock implements CreateSquad {}

class _MockJoinSquad extends Mock implements JoinSquad {}

class _MockLeaveSquad extends Mock implements LeaveSquad {}

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockWatchSquadPresence extends Mock implements WatchSquadPresence {}

class _MockSquadRepository extends Mock implements SquadRepository {}

void main() {
  late _MockWatchMySquad watchMySquad;
  late _MockCreateSquad createSquad;
  late _MockJoinSquad joinSquad;
  late _MockLeaveSquad leaveSquad;
  late _MockWatchLeaderboard watchLeaderboard;
  late _MockWatchSquadPresence watchSquadPresence;
  late _MockSquadRepository squadRepository;

  const squad = Squad(
    id: 'squad-1',
    name: 'Runners',
    inviteCode: 'ABC123',
    ownerId: 'user-1',
  );

  const leaderboardEntry = LeaderboardEntry(
    rank: 1,
    userId: 'user-1',
    displayName: 'You',
    streakTier: StreakTier.none,
    areaSqm: 100,
    isYou: true,
  );

  const presenceMember = SquadPresenceMember(
    userId: 'user-1',
    displayName: 'You',
    activity: 'running',
    avatarUrl: null,
    lat: null,
    lng: null,
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    watchMySquad = _MockWatchMySquad();
    createSquad = _MockCreateSquad();
    joinSquad = _MockJoinSquad();
    leaveSquad = _MockLeaveSquad();
    watchLeaderboard = _MockWatchLeaderboard();
    watchSquadPresence = _MockWatchSquadPresence();
    squadRepository = _MockSquadRepository();

    // Default: no leaderboard/presence activity unless a test overrides it.
    when(() => watchLeaderboard(any())).thenAnswer((_) => const Stream.empty());
    when(
      () => watchSquadPresence(any()),
    ).thenAnswer((_) => const Stream.empty());
  });

  SquadCubit buildCubit() => SquadCubit(
    watchMySquad,
    createSquad,
    joinSquad,
    leaveSquad,
    watchLeaderboard,
    watchSquadPresence,
    squadRepository,
  );

  group('subscribing to watchMySquad', () {
    blocTest<SquadCubit, SquadState>(
      'emits noSquad when the stream reports no squad',
      setUp: () =>
          when(() => watchMySquad()).thenAnswer((_) => Stream.value(null)),
      build: buildCubit,
      expect: () => [
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.noSquad,
        ),
      ],
    );

    blocTest<SquadCubit, SquadState>(
      'emits loaded with the squad, then subscribes leaderboard/presence',
      setUp: () {
        when(() => watchMySquad()).thenAnswer((_) => Stream.value(squad));
        when(
          () => watchLeaderboard(squad.id),
        ).thenAnswer((_) => Stream.value([leaderboardEntry]));
        when(
          () => watchSquadPresence(squad.id),
        ).thenAnswer((_) => Stream.value([presenceMember]));
      },
      build: buildCubit,
      expect: () => [
        isA<SquadState>()
            .having((s) => s.status, 'status', SquadStatus.loaded)
            .having((s) => s.squad, 'squad', squad),
        isA<SquadState>().having(
          (s) => s.leaderboard,
          'leaderboard',
          [leaderboardEntry],
        ),
        isA<SquadState>().having((s) => s.presence, 'presence', [
          presenceMember,
        ]),
      ],
    );

    blocTest<SquadCubit, SquadState>(
      'a genuine stream failure sets status.error with a friendly message, '
      'not a create/join failure being conflated with it',
      setUp: () => when(
        () => watchMySquad(),
      ).thenAnswer((_) => Stream.error(Exception('connection dropped'))),
      build: buildCubit,
      expect: () => [
        isA<SquadState>()
            .having((s) => s.status, 'status', SquadStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('retry', () {
    blocTest<SquadCubit, SquadState>(
      'cancels the old subscription and re-subscribes from loading',
      setUp: () => when(
        () => watchMySquad(),
      ).thenAnswer((_) => Stream.error(Exception('dropped'))),
      build: buildCubit,
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => watchMySquad()).thenAnswer((_) => Stream.value(null));
        await cubit.retry();
      },
      expect: () => [
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.error,
        ),
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.loading,
        ),
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.noSquad,
        ),
      ],
    );
  });

  group('leaveSquad', () {
    blocTest<SquadCubit, SquadState>(
      'toggles isLeavingSquad true then false on success',
      setUp: () {
        when(() => watchMySquad()).thenAnswer((_) => Stream.value(null));
        when(() => leaveSquad(any())).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) async {
        // Let the initial watchMySquad() subscription's noSquad emission
        // settle first, so it doesn't land in the middle of leaveSquad's
        // own emissions (both are scheduled as microtasks).
        await Future<void>.delayed(Duration.zero);
        await cubit.leaveSquad();
      },
      expect: () => [
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.noSquad,
        ),
        isA<SquadState>().having(
          (s) => s.isLeavingSquad,
          'isLeavingSquad',
          true,
        ),
        isA<SquadState>().having(
          (s) => s.isLeavingSquad,
          'isLeavingSquad',
          false,
        ),
      ],
    );

    blocTest<SquadCubit, SquadState>(
      'rethrows on failure and still resets isLeavingSquad — '
      'a dropped connection must not leave the button stuck loading',
      setUp: () {
        when(() => watchMySquad()).thenAnswer((_) => Stream.value(null));
        when(() => leaveSquad(any())).thenThrow(Exception('network error'));
      },
      build: buildCubit,
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        return cubit.leaveSquad();
      },
      expect: () => [
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.noSquad,
        ),
        isA<SquadState>().having(
          (s) => s.isLeavingSquad,
          'isLeavingSquad',
          true,
        ),
        isA<SquadState>().having(
          (s) => s.isLeavingSquad,
          'isLeavingSquad',
          false,
        ),
      ],
      errors: () => [isA<Exception>()],
    );
  });

  group('reportMember', () {
    blocTest<SquadCubit, SquadState>(
      'delegates straight to the repository',
      setUp: () {
        when(() => watchMySquad()).thenAnswer((_) => Stream.value(null));
        when(
          () => squadRepository.reportMember(
            reportedUserId: any(named: 'reportedUserId'),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.reportMember(
        reportedUserId: 'user-2',
        reason: 'spamming the chat',
      ),
      expect: () => [
        isA<SquadState>().having(
          (s) => s.status,
          'status',
          SquadStatus.noSquad,
        ),
      ],
      verify: (_) {
        verify(
          () => squadRepository.reportMember(
            reportedUserId: 'user-2',
            reason: 'spamming the chat',
          ),
        ).called(1);
      },
    );
  });
}
