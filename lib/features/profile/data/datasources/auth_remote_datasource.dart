import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';

/// Thin wrapper over `SupabaseClient.auth` — the only place in the app
/// that touches the Supabase auth SDK (and, for Google linking, the
/// `google_sign_in` SDK) directly.
@lazySingleton
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  var _googleSignInInitialized = false;

  User? get currentUser => _client.auth.currentUser;

  Stream<User?> get userChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user);

  Future<User> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw const AuthDataSourceException('Anonymous sign-in returned no user');
    }
    return user;
  }

  /// Supabase's documented anonymous-upgrade pattern: `updateUser` on an
  /// already-signed-in (anonymous) session attaches email/password
  /// credentials to the *same* user id rather than creating a new account
  /// (plan H8 — no re-keying). Supabase emails a confirmation link; the
  /// identity isn't fully non-anonymous until it's clicked.
  ///
  /// [displayName] is folded into the same `updateUser` call's metadata
  /// (`full_name`) so it lands in the same place Google-linked accounts'
  /// names already live — `_toAppUser` reads from there, not `profiles`.
  /// [syncProfileDisplayName] then copies it to `profiles.display_name`,
  /// the column every cross-user view (leaderboards, squad presence) reads
  /// instead, since `profiles` RLS is select-own-row-only.
  Future<void> linkWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
        data: {'full_name': displayName},
      ),
    );
    await syncProfileDisplayName(displayName);
  }

  /// Signs in as a *returning* linked user — deliberately distinct from
  /// [linkWithEmail]. This replaces whatever session is currently active
  /// (typically a fresh anonymous one) with the real account's session, the
  /// same way Supabase's own `signInWithPassword` always behaves. Without
  /// this, a user who links an account and later loses their local session
  /// (sign out, uninstall, new device) had no way back into their own data.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw const AuthDataSourceException('Sign-in returned no user');
    }
  }

  /// Sends Supabase's built-in password-recovery email. Completing the
  /// reset (setting a new password from the emailed link) currently happens
  /// outside the app — there's no deep-link/App Links handler registered
  /// yet to catch the recovery redirect and land the user back on an
  /// in-app "set new password" screen. That's a real, separate follow-up
  /// (needs `redirect_to` configured in Supabase Auth settings plus an
  /// app-links/universal-links entry on both platforms); this method only
  /// covers "request the email," which is still strictly better than the
  /// previous state of having no reset path at all.
  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Native Google Sign-In (no browser redirect) + Supabase's ID-token
  /// identity linking — the mobile-appropriate flow, distinct from the
  /// web-redirect `getLinkIdentityUrl`/`linkIdentity` pair.
  Future<void> linkWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: Env.googleOAuthClientId,
      );
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthDataSourceException(
        'Google sign-in returned no ID token',
      );
    }
    await _client.auth.linkIdentityWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Signs in as a returning user via Google — the counterpart to
  /// [linkWithGoogle] for someone who already linked Google previously and
  /// lost their local session. Replaces whatever session is currently
  /// active, same as [signInWithPassword].
  Future<void> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: Env.googleOAuthClientId,
      );
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthDataSourceException(
        'Google sign-in returned no ID token',
      );
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Forces a token refresh against Supabase. Needed because claims baked
  /// into the JWT at issuance — notably `is_anonymous` — are only updated
  /// on the *next* refresh, not the moment a linked identity is confirmed
  /// server-side (that confirmation happens out-of-band, via an email link
  /// opened outside the app). Without this, a user who finishes linking
  /// their account keeps seeing "Guest" until the SDK's own background
  /// refresh timer eventually fires (up to the access token's full
  /// lifetime). Call this whenever the app resumes from background, so the
  /// common case — link email, switch to the mail app, tap confirm, come
  /// back — picks up the change immediately. A failure here (e.g. offline)
  /// is not fatal: the existing session keeps working, just with stale
  /// claims until the next successful refresh.
  Future<void> refreshSession() async {
    if (_client.auth.currentSession == null) return;
    await _client.auth.refreshSession();
  }

  /// Best-effort sync of `profiles.display_name` to the name a newly-linked
  /// identity actually carries — `handle_new_user()` only ever populates it
  /// once, at account creation, so a user who starts anonymous (getting a
  /// generated "Runner-XXXXXXXX" placeholder) and later links Google would
  /// otherwise keep that placeholder forever on every leaderboard/squad
  /// view even though a real name is now available. `display_name` carries
  /// a UNIQUE constraint, so a collision here is swallowed rather than
  /// thrown — losing this cosmetic update is preferable to breaking the
  /// link/sign-in flow that triggered it.
  Future<void> syncDisplayNameFromMetadata() async {
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata;
    final name =
        metadata?['full_name'] as String? ?? metadata?['name'] as String?;
    if (user == null || name == null || name.trim().isEmpty) return;
    try {
      await syncProfileDisplayName(name);
    } on PostgrestException {
      // Best-effort — see doc comment above.
    }
  }

  /// Writes [name] to `profiles.display_name` only — the column every
  /// cross-user view (leaderboards, squad presence) reads. Unlike
  /// [syncDisplayNameFromMetadata]'s best-effort swallow (a cosmetic sync
  /// riding along an auth flow that must not fail over it), this is called
  /// from flows where the name *is* the point (sign-up, the profile editor)
  /// — a `display_name` unique-constraint collision propagates so the
  /// caller can tell the user to pick another name instead of silently
  /// losing it.
  Future<void> syncProfileDisplayName(String name) {
    final user = _client.auth.currentUser;
    if (user == null) return Future.value();
    return _client
        .from('profiles')
        .update({'display_name': name})
        .eq('id', user.id);
  }

  /// User-initiated name change (the profile editor) — updates both the
  /// auth metadata `_toAppUser` reads for the signed-in user's own display
  /// (so the change shows immediately without a full re-auth) and
  /// `profiles.display_name` for everyone else's view of this user.
  Future<void> updateDisplayName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
    await syncProfileDisplayName(name);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Calls the `delete-account` Edge Function (deployed server-side with
  /// the service-role key) — the client never holds that key, so account
  /// deletion can't be done as a plain RPC/table call from here.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    final data = response.data;
    if (response.status != 200 || (data is Map && data['error'] != null)) {
      throw AuthDataSourceException(
        'Account deletion failed: ${response.data}',
      );
    }
  }
}

class AuthDataSourceException implements Exception {
  const AuthDataSourceException(this.message);
  final String message;

  @override
  String toString() => 'AuthDataSourceException: $message';
}
