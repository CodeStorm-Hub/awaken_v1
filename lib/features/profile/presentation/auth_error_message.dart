import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps auth failures to copy a user can act on, instead of dumping a raw
/// exception's `toString()` (e.g. `AuthApiException(message: User already
/// registered, statusCode: 422, ...)`) into a SnackBar.
String friendlyAuthErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'That email is already in use — try signing in instead.';
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Check your email and confirm your address before signing in.';
    }
    if (message.contains('password should be at least') ||
        message.contains('should contain')) {
      return error.message;
    }
    if (message.contains('same_password') ||
        message.contains('should be different')) {
      return 'That\'s already your current password.';
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many attempts — please wait a moment and try again.';
    }
    if (message.contains('network') ||
        message.contains('timed out') ||
        message.contains('socket')) {
      return 'Check your connection and try again.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    // 23505 = unique_violation — `profiles.display_name` has a UNIQUE
    // constraint (see `syncProfileDisplayName`'s doc comment).
    if (error.code == '23505' ||
        error.message.toLowerCase().contains('display_name')) {
      return 'That name is already taken — try another.';
    }
  }
  return 'Something went wrong. Please try again.';
}
