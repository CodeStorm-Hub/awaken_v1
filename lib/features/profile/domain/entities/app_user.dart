import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final bool isAnonymous;

  /// Null for anonymous users and for email/password accounts before the
  /// link confirmation completes.
  final String? email;

  /// From the OAuth provider's profile (e.g. Google's `full_name`/`name`).
  /// Null for email/password-only accounts — there's no display name to
  /// pull from those.
  final String? displayName;

  /// From the OAuth provider's profile (e.g. Google's `avatar_url`/
  /// `picture`). Null for email/password-only accounts.
  final String? avatarUrl;

  @override
  List<Object?> get props => [id, isAnonymous, email, displayName, avatarUrl];
}
