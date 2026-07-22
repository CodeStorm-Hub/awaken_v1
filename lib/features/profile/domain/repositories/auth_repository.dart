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

  /// Upgrades the current anonymous session to a real email/password
  /// identity — same `uid`, no re-keying (H8's documented pattern:
  /// `updateUser` on an anonymous session attaches credentials to it rather
  /// than creating a new account). Supabase sends a confirmation email;
  /// the account isn't fully "linked" until the user clicks it.
  Future<void> linkWithEmail({required String email, required String password});

  /// Upgrades the current anonymous session via native Google Sign-In +
  /// ID-token linking (no browser redirect) — same `uid`, no re-keying.
  Future<void> linkWithGoogle();

  /// Ends the remote session. Local Drift data is never touched — this
  /// only signs out of Supabase; the point of the offline-first design is
  /// that local data survives regardless of auth state.
  Future<void> signOut();
}
