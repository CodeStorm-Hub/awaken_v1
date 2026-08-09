import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../sync/local/database.dart';
import '../../../../sync/outbox/sync_worker.dart';
import '../../../../sync/pull/pull_down_sync.dart';
import '../../../alarm/domain/repositories/alarm_repository.dart';
import '../../../squad/domain/repositories/squad_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._db,
    this._pullDownSync,
    this._alarmRepository,
    this._squadRepository,
    this._syncWorker,
  );

  final AuthRemoteDataSource _remote;
  final AppDatabase _db;
  final PullDownSync _pullDownSync;
  final AlarmRepository _alarmRepository;
  final SquadRepository _squadRepository;
  final SyncWorker _syncWorker;

  /// The full account-transition cleanup sequence, shared by
  /// sign-out/sign-in-as-different-user/delete-account: cancel every
  /// natively-scheduled alarm (a stale one could still fire against
  /// now-wiped local data), close squad Realtime channels/cached state,
  /// then wipe the local Drift cache — all held behind `SyncWorker.pauseFor`
  /// so an in-flight outbox drain can't race the wipe.
  Future<void> _clearIdentityState() async {
    await _alarmRepository.cancelAllAlarms();
    await _squadRepository.resetForAccountTransition();
    await _syncWorker.pauseFor(_db.clearAllLocalData);
  }

  AppUser _toAppUser(supabase.User user) {
    final metadata = user.userMetadata;
    return AppUser(
      id: user.id,
      isAnonymous: user.isAnonymous,
      email: user.email,
      // Supabase mirrors whatever the OAuth provider returns verbatim into
      // userMetadata — Google's native id-token flow populates `full_name`
      // and `name` (both, in practice); email/password accounts have
      // neither key at all.
      displayName:
          metadata?['full_name'] as String? ?? metadata?['name'] as String?,
      avatarUrl:
          metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?,
    );
  }

  @override
  AppUser? get currentUser {
    final user = _remote.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Stream<AppUser?> get userChanges =>
      _remote.userChanges.map((user) => user == null ? null : _toAppUser(user));

  @override
  Future<AppUser> ensureSession() async {
    final existing = _remote.currentUser;
    if (existing != null) return _toAppUser(existing);

    final user = await _remote.signInAnonymously();
    return _toAppUser(user);
  }

  @override
  Future<void> refreshSession() => _remote.refreshSession();

  @override
  Future<void> linkWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) => _remote.linkWithEmail(
    email: email,
    password: password,
    displayName: displayName,
  );

  @override
  Future<void> updateDisplayName(String name) =>
      _remote.updateDisplayName(name);

  @override
  Future<void> linkWithGoogle() async {
    await _remote.linkWithGoogle();
    await _remote.syncDisplayNameFromMetadata();
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    // Authenticate first, then clear the outgoing identity's cache and
    // immediately re-hydrate from the incoming account — clearing before
    // the credential check succeeds would wipe local data (alarms,
    // streaks, territory) for a mistyped password with nothing to
    // rehydrate from. Same ordering as signOut()/deleteAccount() below:
    // only destroy state once the remote call it depends on has committed.
    await _remote.signInWithPassword(email: email, password: password);
    await _clearIdentityState();
    await _pullDownSync.run();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _remote.sendPasswordResetEmail(email);

  @override
  Future<void> signInWithGoogle() async {
    // See signInWithPassword above — authenticate before clearing so a
    // cancelled/failed Google OAuth dialog doesn't wipe local data.
    await _remote.signInWithGoogle();
    await _clearIdentityState();
    await _remote.syncDisplayNameFromMetadata();
    await _pullDownSync.run();
  }

  @override
  Future<void> signOut() async {
    await _remote.signOut();
    // Clear after signOut succeeds so a failed signOut doesn't strand the
    // user mid-wipe. See `_clearIdentityState`'s doc comment for why this
    // is more than just the Drift wipe.
    await _clearIdentityState();
    // The app's whole model is "every user always has a session" (plan
    // H8) — that invariant only gets re-established automatically at the
    // next cold start (bootstrap's EnsureAuthSession). Without this, a
    // user who signs out mid-session is left with `currentUser == null`
    // until they force-quit and relaunch: "Migrate to cloud"/"Sign in"
    // would fail outright (nothing to attach an identity *to*), and the
    // Profile UI's `isAnonymous ?? true` fallback masks this as an
    // ordinary "Guest" state instead of "not signed in at all". Found via
    // live testing — signing out then immediately trying to link Google
    // failed with GoTrue's "Linking requires a valid user access token".
    await ensureSession();
  }

  @override
  Future<void> deleteAccount() async {
    await _remote.deleteAccount();
    await _remote.signOut();
    await _clearIdentityState();
    await ensureSession();
  }
}
