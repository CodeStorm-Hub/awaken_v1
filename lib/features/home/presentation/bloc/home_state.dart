import 'package:equatable/equatable.dart';

import '../../../squad/domain/entities/squad.dart';
import '../../domain/entities/recent_activity_entry.dart';

/// Combines every stream `HomePage` reads (previously four independently
/// nested `StreamBuilder`s, including two separate subscriptions to
/// `WatchOwnedArea` for the stat tile and the achievements row) into one
/// state object, matching the `ThemeModeCubit`/`SquadCubit` Cubit pattern
/// used elsewhere instead of calling use cases directly from a
/// `StatelessWidget` via `getIt`.
class HomeState extends Equatable {
  const HomeState({
    this.streak = 0,
    this.streakError = false,
    this.ownedAreaSqm = 0,
    this.ownedAreaError = false,
    this.squadRank,
    this.squadRankError = false,
    this.squad,
    this.squadError = false,
    this.recentActivity = const [],
    this.recentActivityError = false,
  });

  final int streak;
  final bool streakError;
  final double ownedAreaSqm;
  final bool ownedAreaError;
  final int? squadRank;
  final bool squadRankError;
  final Squad? squad;
  final bool squadError;
  final List<RecentActivityEntry> recentActivity;
  final bool recentActivityError;

  HomeState copyWith({
    int? streak,
    bool? streakError,
    double? ownedAreaSqm,
    bool? ownedAreaError,
    int? squadRank,
    bool clearSquadRank = false,
    bool? squadRankError,
    Squad? squad,
    bool clearSquad = false,
    bool? squadError,
    List<RecentActivityEntry>? recentActivity,
    bool? recentActivityError,
  }) {
    return HomeState(
      streak: streak ?? this.streak,
      streakError: streakError ?? this.streakError,
      ownedAreaSqm: ownedAreaSqm ?? this.ownedAreaSqm,
      ownedAreaError: ownedAreaError ?? this.ownedAreaError,
      squadRank: clearSquadRank ? null : (squadRank ?? this.squadRank),
      squadRankError: squadRankError ?? this.squadRankError,
      squad: clearSquad ? null : (squad ?? this.squad),
      squadError: squadError ?? this.squadError,
      recentActivity: recentActivity ?? this.recentActivity,
      recentActivityError: recentActivityError ?? this.recentActivityError,
    );
  }

  @override
  List<Object?> get props => [
    streak,
    streakError,
    ownedAreaSqm,
    ownedAreaError,
    squadRank,
    squadRankError,
    squad,
    squadError,
    recentActivity,
    recentActivityError,
  ];
}
