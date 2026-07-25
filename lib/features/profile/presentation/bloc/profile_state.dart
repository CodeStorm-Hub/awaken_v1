import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

/// Combines the streams `ProfilePage` reads (streak, territory area,
/// current user) into one state object, matching the `HomeCubit`/
/// `SquadCubit` Cubit pattern instead of nested `StreamBuilder`s calling
/// use cases directly via `getIt`.
class ProfileState extends Equatable {
  const ProfileState({
    this.streak = 0,
    this.streakError = false,
    this.ownedAreaSqm = 0,
    this.ownedAreaError = false,
    this.user,
  });

  final int streak;
  final bool streakError;
  final double ownedAreaSqm;
  final bool ownedAreaError;
  final AppUser? user;

  ProfileState copyWith({
    int? streak,
    bool? streakError,
    double? ownedAreaSqm,
    bool? ownedAreaError,
    AppUser? user,
    bool clearUser = false,
  }) {
    return ProfileState(
      streak: streak ?? this.streak,
      streakError: streakError ?? this.streakError,
      ownedAreaSqm: ownedAreaSqm ?? this.ownedAreaSqm,
      ownedAreaError: ownedAreaError ?? this.ownedAreaError,
      user: clearUser ? null : (user ?? this.user),
    );
  }

  @override
  List<Object?> get props => [
    streak,
    streakError,
    ownedAreaSqm,
    ownedAreaError,
    user,
  ];
}
