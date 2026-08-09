import 'package:equatable/equatable.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_presence_member.dart';

enum SquadStatus {
  /// Fetching whether the user already has a squad.
  loading,

  /// Every real account starts here — create or join, no squad yet.
  noSquad,

  /// In a squad; `squad`/`leaderboard`/`presence` are populated.
  loaded,

  error,
}

class SquadState extends Equatable {
  const SquadState({
    this.status = SquadStatus.loading,
    this.squad,
    this.leaderboard = const [],
    this.presence = const [],
    this.errorMessage,
    this.isLeavingSquad = false,
    this.refreshFailed = false,
  });

  final SquadStatus status;
  final Squad? squad;
  final List<LeaderboardEntry> leaderboard;
  final List<SquadPresenceMember> presence;
  final String? errorMessage;

  /// True only while a "Leave squad" call is in flight — kept separate
  /// from [status] so a failed leave attempt shows an inline SnackBar
  /// instead of blowing away the still-current `loaded` squad view.
  final bool isLeavingSquad;

  /// One-shot flag: a *background* refresh of the current squad failed
  /// (see `SquadRepository.refreshFailures`) while still-current data is
  /// shown. Separate from [status]/[errorMessage] for the same reason as
  /// [isLeavingSquad] — this must not replace the `loaded` view, only
  /// prompt a transient SnackBar. The listener that shows it is expected
  /// to clear it back to `false` via `SquadCubit.dismissRefreshFailure()`.
  final bool refreshFailed;

  SquadState copyWith({
    SquadStatus? status,
    Squad? squad,
    bool clearSquad = false,
    List<LeaderboardEntry>? leaderboard,
    List<SquadPresenceMember>? presence,
    String? errorMessage,
    bool? isLeavingSquad,
    bool? refreshFailed,
  }) {
    return SquadState(
      status: status ?? this.status,
      squad: clearSquad ? null : (squad ?? this.squad),
      leaderboard: leaderboard ?? this.leaderboard,
      presence: presence ?? this.presence,
      errorMessage: errorMessage ?? this.errorMessage,
      isLeavingSquad: isLeavingSquad ?? this.isLeavingSquad,
      refreshFailed: refreshFailed ?? this.refreshFailed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    squad,
    leaderboard,
    presence,
    errorMessage,
    isLeavingSquad,
    refreshFailed,
  ];
}
