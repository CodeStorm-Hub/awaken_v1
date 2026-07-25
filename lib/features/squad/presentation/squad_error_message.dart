import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps squad RPC/network failures to copy a user can act on, instead of
/// dumping a raw exception's `toString()` (e.g.
/// `PostgrestException(message: invalid invite code, code: P0001, ...)`)
/// into UI text — same rationale as `auth_error_message.dart`.
String friendlySquadErrorMessage(Object error) {
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('invite code')) {
      return "That invite code doesn't look right — check it and try again.";
    }
    if (message.contains('already in a squad') || message.contains('already a member')) {
      return "You're already in a squad — leave it first to join another.";
    }
    if (message.contains('not a member')) {
      return "You're not a member of this squad anymore.";
    }
    if (message.contains('not authenticated')) {
      return 'Please sign in and try again.';
    }
    if (message.contains('network') || message.contains('timed out') || message.contains('socket')) {
      return 'Check your connection and try again.';
    }
    return error.message;
  }
  if (error is SocketException) {
    return 'Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
