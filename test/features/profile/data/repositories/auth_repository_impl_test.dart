import 'package:awaken/features/alarm/domain/repositories/alarm_repository.dart';
import 'package:awaken/features/profile/data/datasources/auth_remote_datasource.dart';
import 'package:awaken/features/profile/data/repositories/auth_repository_impl.dart';
import 'package:awaken/features/squad/domain/repositories/squad_repository.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/sync_worker.dart';
import 'package:awaken/sync/pull/pull_down_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockPullDownSync extends Mock implements PullDownSync {}

class _MockAlarmRepository extends Mock implements AlarmRepository {}

class _MockSquadRepository extends Mock implements SquadRepository {}

class _MockSyncWorker extends Mock implements SyncWorker {}

supabase.User _fakeUser({
  String id = 'user-1',
  bool isAnonymous = false,
  String? email,
  Map<String, dynamic>? userMetadata,
}) {
  return supabase.User(
    id: id,
    appMetadata: const {},
    userMetadata: userMetadata,
    aud: 'authenticated',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
    email: email,
    isAnonymous: isAnonymous,
  );
}

void main() {
  late _MockAuthRemoteDataSource remote;
  late _MockAppDatabase db;
  late _MockPullDownSync pullDownSync;
  late _MockAlarmRepository alarmRepository;
  late _MockSquadRepository squadRepository;
  late _MockSyncWorker syncWorker;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _MockAuthRemoteDataSource();
    db = _MockAppDatabase();
    pullDownSync = _MockPullDownSync();
    alarmRepository = _MockAlarmRepository();
    squadRepository = _MockSquadRepository();
    syncWorker = _MockSyncWorker();
    repository = AuthRepositoryImpl(
      remote,
      db,
      pullDownSync,
      alarmRepository,
      squadRepository,
      syncWorker,
    );

    // `_clearIdentityState`'s SyncWorker.pauseFor must actually invoke the
    // passed transition (AppDatabase.clearAllLocalData) for the identity
    // wipe to happen — not just record that pauseFor was called.
    when(() => syncWorker.pauseFor<void>(any())).thenAnswer((invocation) {
      final transition =
          invocation.positionalArguments[0] as Future<void> Function();
      return transition();
    });
    when(() => db.clearAllLocalData()).thenAnswer((_) async {});
    when(() => alarmRepository.cancelAllAlarms()).thenAnswer((_) async {});
    when(
      () => squadRepository.resetForAccountTransition(),
    ).thenAnswer((_) async {});
    when(() => pullDownSync.run()).thenAnswer((_) async {});
  });

  group('user mapping', () {
    test(
      'currentUser prefers full_name over name, avatar_url over picture',
      () {
        when(() => remote.currentUser).thenReturn(
          _fakeUser(
            userMetadata: {
              'full_name': 'Real Name',
              'name': 'Fallback Name',
              'avatar_url': 'https://real.example/a.png',
              'picture': 'https://fallback.example/b.png',
            },
          ),
        );

        final user = repository.currentUser;

        expect(user!.displayName, 'Real Name');
        expect(user.avatarUrl, 'https://real.example/a.png');
      },
    );

    test(
      'currentUser falls back to name/picture when full_name/avatar_url '
      'are absent (email/password accounts carry neither full_name nor '
      'avatar_url at all)',
      () {
        when(() => remote.currentUser).thenReturn(
          _fakeUser(userMetadata: {'name': 'Only Name', 'picture': 'only.png'}),
        );

        final user = repository.currentUser;

        expect(user!.displayName, 'Only Name');
        expect(user.avatarUrl, 'only.png');
      },
    );

    test('currentUser is null when no session', () {
      when(() => remote.currentUser).thenReturn(null);
      expect(repository.currentUser, isNull);
    });
  });

  group('ensureSession', () {
    test('returns the existing user without signing in anonymously', () async {
      when(() => remote.currentUser).thenReturn(_fakeUser(id: 'existing'));

      final user = await repository.ensureSession();

      expect(user.id, 'existing');
      verifyNever(() => remote.signInAnonymously());
    });

    test('signs in anonymously when there is no session', () async {
      when(() => remote.currentUser).thenReturn(null);
      when(
        () => remote.signInAnonymously(),
      ).thenAnswer((_) async => _fakeUser(id: 'new-anon', isAnonymous: true));

      final user = await repository.ensureSession();

      expect(user.id, 'new-anon');
      expect(user.isAnonymous, isTrue);
    });
  });

  group('signInWithPassword', () {
    test(
      'clears the outgoing identity before signing in, then re-hydrates '
      'from the incoming account — a stale identity must never be left '
      'in the local cache once a different account is signed into',
      () async {
        when(
          () => remote.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async {});

        await repository.signInWithPassword(
          email: 'a@b.com',
          password: 'hunter2',
        );

        verifyInOrder([
          () => alarmRepository.cancelAllAlarms(),
          () => squadRepository.resetForAccountTransition(),
          () => db.clearAllLocalData(),
          () => remote.signInWithPassword(email: 'a@b.com', password: 'hunter2'),
          () => pullDownSync.run(),
        ]);
      },
    );
  });

  group('signOut', () {
    test(
      'signs out remotely, wipes local state, then re-establishes a '
      'session — regression test for a live bug where skipping the final '
      'ensureSession() left the app with currentUser == null until a '
      'force-quit/relaunch, breaking "Sign in"/"Migrate to cloud" '
      'immediately after signing out',
      () async {
        when(() => remote.signOut()).thenAnswer((_) async {});
        // ensureSession()'s own call, invoked after the wipe.
        when(() => remote.currentUser).thenReturn(null);
        when(
          () => remote.signInAnonymously(),
        ).thenAnswer((_) async => _fakeUser(id: 're-anon', isAnonymous: true));

        await repository.signOut();

        verifyInOrder([
          () => remote.signOut(),
          () => alarmRepository.cancelAllAlarms(),
          () => squadRepository.resetForAccountTransition(),
          () => db.clearAllLocalData(),
          () => remote.signInAnonymously(),
        ]);
      },
    );
  });

  group('deleteAccount', () {
    test(
      'deletes remotely, signs out, wipes local state, then re-establishes '
      'a session — same "always have a session" invariant as signOut',
      () async {
        when(() => remote.deleteAccount()).thenAnswer((_) async {});
        when(() => remote.signOut()).thenAnswer((_) async {});
        when(() => remote.currentUser).thenReturn(null);
        when(
          () => remote.signInAnonymously(),
        ).thenAnswer((_) async => _fakeUser(id: 're-anon', isAnonymous: true));

        await repository.deleteAccount();

        verifyInOrder([
          () => remote.deleteAccount(),
          () => remote.signOut(),
          () => alarmRepository.cancelAllAlarms(),
          () => squadRepository.resetForAccountTransition(),
          () => db.clearAllLocalData(),
          () => remote.signInAnonymously(),
        ]);
      },
    );
  });
}
