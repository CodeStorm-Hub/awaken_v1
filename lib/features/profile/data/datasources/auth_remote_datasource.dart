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
  Future<void> linkWithEmail({required String email, required String password}) async {
    await _client.auth.updateUser(UserAttributes(email: email, password: password));
  }

  /// Signs in as a *returning* linked user — deliberately distinct from
  /// [linkWithEmail]. This replaces whatever session is currently active
  /// (typically a fresh anonymous one) with the real account's session, the
  /// same way Supabase's own `signInWithPassword` always behaves. Without
  /// this, a user who links an account and later loses their local session
  /// (sign out, uninstall, new device) had no way back into their own data.
  Future<void> signInWithPassword({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
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
      await GoogleSignIn.instance.initialize(serverClientId: Env.googleOAuthClientId);
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthDataSourceException('Google sign-in returned no ID token');
    }
    await _client.auth.linkIdentityWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  }

  /// Signs in as a returning user via Google — the counterpart to
  /// [linkWithGoogle] for someone who already linked Google previously and
  /// lost their local session. Replaces whatever session is currently
  /// active, same as [signInWithPassword].
  Future<void> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(serverClientId: Env.googleOAuthClientId);
      _googleSignInInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthDataSourceException('Google sign-in returned no ID token');
    }
    await _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
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

  Future<void> signOut() => _client.auth.signOut();

  /// Calls the `delete-account` Edge Function (deployed server-side with
  /// the service-role key) — the client never holds that key, so account
  /// deletion can't be done as a plain RPC/table call from here.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    final data = response.data;
    if (response.status != 200 || (data is Map && data['error'] != null)) {
      throw AuthDataSourceException('Account deletion failed: ${response.data}');
    }
  }
}

class AuthDataSourceException implements Exception {
  const AuthDataSourceException(this.message);
  final String message;

  @override
  String toString() => 'AuthDataSourceException: $message';
}
