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
  ///
  /// Linking an anonymous session to a real identity (email/OAuth) is a
  /// Phase 3 concern (plan §6) — not implemented here yet.
  Future<AppUser> ensureSession();
}
