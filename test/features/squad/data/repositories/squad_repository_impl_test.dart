import 'dart:async';

import 'package:awaken/features/squad/data/datasources/squad_remote_datasource.dart';
import 'package:awaken/features/squad/data/repositories/squad_repository_impl.dart';
import 'package:awaken/features/squad/domain/entities/squad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSquadRemoteDataSource extends Mock
    implements SquadRemoteDataSource {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

Map<String, dynamic> _squadJson({
  String id = 'squad-1',
  String name = 'Runners',
  String inviteCode = 'ABC123',
  String ownerId = 'owner-1',
}) => {
  'id': id,
  'name': name,
  'invite_code': inviteCode,
  'owner_id': ownerId,
};

Map<String, dynamic> _leaderboardRow({
  required String userId,
  required double areaSqm,
  String? displayName,
}) => {
  'user_id': userId,
  'display_name': displayName,
  'area_sqm': areaSqm,
  'streak_tier': 0,
  'avatar_url': null,
};

void main() {
  late _MockSquadRemoteDataSource remote;
  late _MockSupabaseClient supabase;
  late _MockGoTrueClient auth;
  late SquadRepositoryImpl repository;

  setUp(() {
    remote = _MockSquadRemoteDataSource();
    supabase = _MockSupabaseClient();
    auth = _MockGoTrueClient();

    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);

    repository = SquadRepositoryImpl(remote, supabase);
  });

  group('leaderboard mapping — standard competition ranking', () {
    test('ties share a rank and the following entry skips ahead', () async {
      when(
        () => remote.fetchGlobalLeaderboard(
          timeWindow: any(named: 'timeWindow'),
          rowLimit: any(named: 'rowLimit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _leaderboardRow(userId: 'a', areaSqm: 100),
          _leaderboardRow(userId: 'b', areaSqm: 100),
          _leaderboardRow(userId: 'c', areaSqm: 50),
        ],
      );

      final result = await repository.fetchGlobalLeaderboard(
        timeWindow: 'all_time',
      );

      expect(result.map((e) => e.rank).toList(), [1, 1, 3]);
    });

    test('rankOffset shifts ranks for a paginated request', () async {
      when(
        () => remote.fetchNearbyLeaderboard(
          radiusM: any(named: 'radiusM'),
          timeWindow: any(named: 'timeWindow'),
          rowLimit: any(named: 'rowLimit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _leaderboardRow(userId: 'd', areaSqm: 40),
          _leaderboardRow(userId: 'e', areaSqm: 30),
        ],
      );

      final result = await repository.fetchNearbyLeaderboard(
        radiusM: 5000,
        timeWindow: 'weekly',
        offset: 50,
      );

      expect(result.map((e) => e.rank).toList(), [51, 52]);
    });

    test('defaultName fills in a null display_name', () async {
      when(
        () => remote.fetchGlobalLeaderboard(
          timeWindow: any(named: 'timeWindow'),
          rowLimit: any(named: 'rowLimit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [_leaderboardRow(userId: 'f', areaSqm: 10)],
      );

      final result = await repository.fetchGlobalLeaderboard(
        timeWindow: 'all_time',
      );

      expect(result.single.displayName, 'Player');
    });

    test('marks the signed-in user\'s own row as isYou', () async {
      final user = _MockUser();
      when(() => user.id).thenReturn('me');
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => remote.fetchGlobalLeaderboard(
          timeWindow: any(named: 'timeWindow'),
          rowLimit: any(named: 'rowLimit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _leaderboardRow(userId: 'me', areaSqm: 10),
          _leaderboardRow(userId: 'someone-else', areaSqm: 5),
        ],
      );

      final result = await repository.fetchGlobalLeaderboard(
        timeWindow: 'all_time',
      );

      expect(result.firstWhere((e) => e.userId == 'me').isYou, isTrue);
      expect(
        result.firstWhere((e) => e.userId == 'someone-else').isYou,
        isFalse,
      );
    });
  });

  group('watchMySquad — broadcast late-subscriber replay', () {
    test(
      'a listener subscribing after the first emission still gets the '
      'last known value instead of waiting forever (regression: found via '
      'live device testing when two independent listeners raced the '
      'one-shot fetch)',
      () async {
        // currentUser is null (default stub), so `_refreshMySquad` emits
        // `null` immediately without touching any Postgrest query.
        final first = await repository.watchMySquad().first;
        expect(first, isNull);

        // Second subscriber attaches *after* the first emission already
        // happened — must still see the replayed value, not hang.
        final second = await repository
            .watchMySquad()
            .timeout(const Duration(seconds: 2))
            .first;
        expect(second, isNull);
      },
    );
  });

  group('createSquad / joinSquad / leaveSquad', () {
    test('createSquad delegates to remote and emits the new squad', () async {
      when(
        () => remote.createSquad(any()),
      ).thenAnswer((_) async => _squadJson());

      final events = <Squad?>[];
      final sub = repository.watchMySquad().listen(events.add);
      addTearDown(sub.cancel);
      // Let the fetch-once null (no signed-in user) flow through first.
      await Future<void>.delayed(Duration.zero);

      final squad = await repository.createSquad('Runners');
      await Future<void>.delayed(Duration.zero);

      expect(squad.id, 'squad-1');
      expect(squad.name, 'Runners');
      expect(events.last, squad);
    });

    test('joinSquad delegates to remote and emits the joined squad', () async {
      when(
        () => remote.joinSquad(any()),
      ).thenAnswer((_) async => _squadJson(id: 'squad-2'));

      final squad = await repository.joinSquad('ABC123');

      expect(squad.id, 'squad-2');
    });

    test('leaveSquad delegates to remote and emits null', () async {
      when(() => remote.leaveSquad()).thenAnswer((_) async {});
      when(
        () => remote.createSquad(any()),
      ).thenAnswer((_) async => _squadJson());
      await repository.createSquad('Runners');

      final events = <Squad?>[];
      final sub = repository.watchMySquad().listen(events.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      await repository.leaveSquad();
      await Future<void>.delayed(Duration.zero);

      expect(events.last, isNull);
    });
  });

  group('watchPresence — Presence + Broadcast merge', () {
    test(
      'combines presence roster with the latest broadcast activity label',
      () async {
        final presenceController =
            StreamController<List<SinglePresenceState>>();
        final broadcastController = StreamController<Map<String, dynamic>>();
        addTearDown(presenceController.close);
        addTearDown(broadcastController.close);

        when(
          () => remote.watchPresenceState('squad-1'),
        ).thenAnswer((_) => presenceController.stream);
        when(
          () => remote.watchBroadcast('squad-1'),
        ).thenAnswer((_) => broadcastController.stream);

        final events = <List<dynamic>>[];
        final sub = repository
            .watchPresence('squad-1')
            .listen((members) => events.add(members));
        addTearDown(sub.cancel);

        presenceController.add([
          SinglePresenceState(
            key: 'user-1',
            presences: [
              Presence(
                presenceRef: 'ref-1',
                payload: {
                  'user_id': 'user-1',
                  'display_name': 'Alex',
                  'activity': 'Idle',
                },
              ),
            ],
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(events.last, hasLength(1));
        expect((events.last.single as dynamic).activity, 'Idle');

        broadcastController.add({'user_id': 'user-1', 'label': 'Running 2km'});
        await Future<void>.delayed(Duration.zero);

        expect((events.last.single as dynamic).activity, 'Running 2km');
      },
    );
  });

  group('trackPresence / broadcastTelemetry — no squad no-ops', () {
    test('trackPresence is a no-op with no cached squad', () async {
      await repository.trackPresence(activity: 'Running');
      verifyNever(() => remote.trackPresence(any(), any()));
    });

    test('broadcastTelemetry is a no-op with no cached squad', () {
      repository.broadcastTelemetry(label: 'Running 1km');
      verifyNever(() => remote.broadcastTelemetry(any(), any()));
    });

    test('broadcastTelemetry throttles rapid repeated calls', () async {
      when(
        () => remote.createSquad(any()),
      ).thenAnswer((_) async => _squadJson());
      final user = _MockUser();
      when(() => user.id).thenReturn('me');
      when(() => auth.currentUser).thenReturn(user);
      when(() => remote.broadcastTelemetry(any(), any())).thenReturn(null);
      await repository.createSquad('Runners');

      repository.broadcastTelemetry(label: 'Running 1km');
      repository.broadcastTelemetry(label: 'Running 2km');

      verify(() => remote.broadcastTelemetry(any(), any())).called(1);
    });
  });

  group('resetForAccountTransition', () {
    test('clears cached squad so a stale identity cannot leak', () async {
      when(
        () => remote.createSquad(any()),
      ).thenAnswer((_) async => _squadJson());
      when(() => remote.closeAllChannels()).thenAnswer((_) async {});
      await repository.createSquad('Runners');

      await repository.resetForAccountTransition();

      await repository.trackPresence(activity: 'Running');
      verifyNever(() => remote.trackPresence(any(), any()));
      verify(() => remote.closeAllChannels()).called(1);
    });
  });

  group('reportMember', () {
    test('no-ops with no cached squad', () async {
      await repository.reportMember(reportedUserId: 'u2', reason: 'spam');
      verifyNever(
        () => remote.reportMember(
          reporterId: any(named: 'reporterId'),
          reportedUserId: any(named: 'reportedUserId'),
          squadId: any(named: 'squadId'),
          reason: any(named: 'reason'),
        ),
      );
    });

    test('delegates to remote with the cached squad id once in a squad', () async {
      when(
        () => remote.createSquad(any()),
      ).thenAnswer((_) async => _squadJson(id: 'squad-9'));
      final user = _MockUser();
      when(() => user.id).thenReturn('me');
      when(() => auth.currentUser).thenReturn(user);
      when(
        () => remote.reportMember(
          reporterId: any(named: 'reporterId'),
          reportedUserId: any(named: 'reportedUserId'),
          squadId: any(named: 'squadId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      await repository.createSquad('Runners');

      await repository.reportMember(reportedUserId: 'u2', reason: 'spam');

      verify(
        () => remote.reportMember(
          reporterId: 'me',
          reportedUserId: 'u2',
          squadId: 'squad-9',
          reason: 'spam',
        ),
      ).called(1);
    });
  });
}
