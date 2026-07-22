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

  Future<void> signOut() => _client.auth.signOut();
}

class AuthDataSourceException implements Exception {
  const AuthDataSourceException(this.message);
  final String message;

  @override
  String toString() => 'AuthDataSourceException: $message';
}
