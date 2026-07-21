import 'package:equatable/equatable.dart';

/// Base type for all domain-layer failures. Repositories return
/// `Either<Failure, T>`-style results (or throw these) instead of leaking
/// Supabase/Drift/platform exceptions past the data layer.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class LocalStorageFailure extends Failure {
  const LocalStorageFailure([super.message = 'Local storage error']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error']);
}

class SyncFailure extends Failure {
  const SyncFailure([super.message = 'Sync error']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Required permission not granted']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication error']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation error']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Unexpected error']);
}
