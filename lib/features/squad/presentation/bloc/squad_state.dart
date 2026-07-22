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
  });

  final SquadStatus status;
  final Squad? squad;
  final List<LeaderboardEntry> leaderboard;
  final List<SquadPresenceMember> presence;
  final String? errorMessage;

  SquadState copyWith({
    SquadStatus? status,
    Squad? squad,
    bool clearSquad = false,
    List<LeaderboardEntry>? leaderboard,
    List<SquadPresenceMember>? presence,
    String? errorMessage,
  }) {
    return SquadState(
      status: status ?? this.status,
      squad: clearSquad ? null : (squad ?? this.squad),
      leaderboard: leaderboard ?? this.leaderboard,
      presence: presence ?? this.presence,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, squad, leaderboard, presence, errorMessage];
}
