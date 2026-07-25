import '../entities/app_user.dart';

/// Domain-facing auth contract. The rest of the app never touches
/// `SupabaseClient.auth` directly — only this interface.
abstract interface class AuthRepository {
  /// The currently signed-in user, if any.
  AppUser? get currentUser;

  /// Emits whenever the auth state changes (sign-in, sign-out, token
  /// refresh, anonymous→linked upgrade).
  Stream<AppUser?> get userChanges;

  /// Guarantees a session exists, signing in anonymously if needed (plan
  /// H8: anonymous-first over the error-prone guest re-key routine).
  /// Returns the resulting user.
  Future<AppUser> ensureSession();

  /// Forces a token refresh so JWT claims (notably `is_anonymous`) reflect
  /// server-side state that changed out-of-band, e.g. an email-link
  /// confirmation completed in a browser/mail app while this app was
  /// backgrounded. No-ops if there's no active session. See
  /// `AuthRemoteDataSource.refreshSession` for the full rationale.
  Future<void> refreshSession();

  /// Upgrades the current anonymous session to a real email/password
  /// identity — same `uid`, no re-keying (H8's documented pattern:
  /// `updateUser` on an anonymous session attaches credentials to it rather
  /// than creating a new account). Supabase sends a confirmation email;
  /// the account isn't fully "linked" until the user clicks it.
  Future<void> linkWithEmail({required String email, required String password});

  /// Signs in as a returning linked user, replacing whatever session
  /// (typically anonymous) is currently active. The counterpart to
  /// [linkWithEmail] that was previously missing entirely.
  Future<void> signInWithPassword({required String email, required String password});

  /// Requests a password-recovery email for an existing linked account.
  Future<void> sendPasswordResetEmail(String email);

  /// Upgrades the current anonymous session via native Google Sign-In +
  /// ID-token linking (no browser redirect) — same `uid`, no re-keying.
  Future<void> linkWithGoogle();

  /// Signs in as a returning user via Google, replacing whatever session is
  /// currently active. The counterpart to [linkWithGoogle] that was
  /// previously missing.
  Future<void> signInWithGoogle();

  /// Ends the remote session and clears the local Drift cache — the local
  /// store has no per-user scoping (single-identity cache, not a
  /// multi-tenant store), so leaving it in place would let the next
  /// session on this device see the outgoing identity's data.
  Future<void> signOut();

  /// Permanently deletes the signed-in user's account and all associated
  /// server-side data (Google Play User Data policy / Apple Guideline
  /// 5.1.1 — in-app self-service deletion, not just deactivation). Calls
  /// the `delete-account` Edge Function, which runs with the service-role
  /// key server-side; this method never has that key itself. Local Drift
  /// data is left untouched by the deletion call itself, but the caller
  /// signs out immediately after, same as `signOut()`.
  Future<void> deleteAccount();
}
