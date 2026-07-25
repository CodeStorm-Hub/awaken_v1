import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../sync/local/database.dart';
import '../../../../sync/pull/pull_down_sync.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._db, this._pullDownSync);

  final AuthRemoteDataSource _remote;
  final AppDatabase _db;
  final PullDownSync _pullDownSync;

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
      displayName: metadata?['full_name'] as String? ?? metadata?['name'] as String?,
      avatarUrl: metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?,
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
  Future<void> linkWithEmail({required String email, required String password}) =>
      _remote.linkWithEmail(email: email, password: password);

  @override
  Future<void> linkWithGoogle() => _remote.linkWithGoogle();

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    // Switching identity mid-session (not a cold start) carries the same
    // cross-account leakage risk as sign-out — clear the outgoing
    // identity's cache first, then immediately re-hydrate from the
    // incoming account so the user isn't staring at an empty app until
    // their next cold start (PullDownSync otherwise only runs from
    // bootstrap).
    await _db.clearAllLocalData();
    await _remote.signInWithPassword(email: email, password: password);
    await _pullDownSync.run();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _remote.sendPasswordResetEmail(email);

  @override
  Future<void> signInWithGoogle() async {
    await _db.clearAllLocalData();
    await _remote.signInWithGoogle();
    await _pullDownSync.run();
  }

  @override
  Future<void> signOut() async {
    await _remote.signOut();
    // Local Drift data has no per-user scoping (it's a single-identity
    // cache, not a multi-tenant store) — leaving it in place would let the
    // next anonymous/linked session on this device see, and even re-upload
    // via the outbox, the previous identity's data. Clear after signOut
    // succeeds so a failed signOut doesn't strand the user mid-wipe.
    await _db.clearAllLocalData();
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
    await _db.clearAllLocalData();
    await ensureSession();
  }
}
