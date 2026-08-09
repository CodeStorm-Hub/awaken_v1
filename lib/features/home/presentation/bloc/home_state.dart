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
    this.streakLoading = true,
    this.ownedAreaSqm = 0,
    this.ownedAreaError = false,
    this.ownedAreaLoading = true,
    this.squadRank,
    this.squadRankError = false,
    this.squad,
    this.squadError = false,
    this.recentActivity = const [],
    this.recentActivityError = false,
    this.recentActivityLoading = true,
    this.wakeUpTaxMultiplier = 1.0,
  });

  final int streak;
  final bool streakError;

  /// True until `_watchCurrentStreak`'s stream produces its first value (or
  /// error). Distinguishes "still loading" from a genuine zero-streak empty
  /// state — see the class doc on why the two used to render identically.
  final bool streakLoading;

  final double ownedAreaSqm;
  final bool ownedAreaError;

  /// See [streakLoading] — same first-value gate for `_watchOwnedArea`.
  final bool ownedAreaLoading;

  final int? squadRank;
  final bool squadRankError;
  final Squad? squad;
  final bool squadError;
  final List<RecentActivityEntry> recentActivity;
  final bool recentActivityError;

  /// See [streakLoading] — same first-value gate for `_watchRecentActivity`.
  final bool recentActivityLoading;

  /// Current wake-up-tax multiplier (`WakeUpTaxStore.watch()`), 1.0 == no
  /// active penalty. Fed to `WakeUpTaxMeter`, which already renders nothing
  /// at the 1.0 floor.
  final double wakeUpTaxMultiplier;

  HomeState copyWith({
    int? streak,
    bool? streakError,
    bool? streakLoading,
    double? ownedAreaSqm,
    bool? ownedAreaError,
    bool? ownedAreaLoading,
    int? squadRank,
    bool clearSquadRank = false,
    bool? squadRankError,
    Squad? squad,
    bool clearSquad = false,
    bool? squadError,
    List<RecentActivityEntry>? recentActivity,
    bool? recentActivityError,
    bool? recentActivityLoading,
    double? wakeUpTaxMultiplier,
  }) {
    return HomeState(
      streak: streak ?? this.streak,
      streakError: streakError ?? this.streakError,
      streakLoading: streakLoading ?? this.streakLoading,
      ownedAreaSqm: ownedAreaSqm ?? this.ownedAreaSqm,
      ownedAreaError: ownedAreaError ?? this.ownedAreaError,
      ownedAreaLoading: ownedAreaLoading ?? this.ownedAreaLoading,
      squadRank: clearSquadRank ? null : (squadRank ?? this.squadRank),
      squadRankError: squadRankError ?? this.squadRankError,
      squad: clearSquad ? null : (squad ?? this.squad),
      squadError: squadError ?? this.squadError,
      recentActivity: recentActivity ?? this.recentActivity,
      recentActivityError: recentActivityError ?? this.recentActivityError,
      recentActivityLoading:
          recentActivityLoading ?? this.recentActivityLoading,
      wakeUpTaxMultiplier: wakeUpTaxMultiplier ?? this.wakeUpTaxMultiplier,
    );
  }

  @override
  List<Object?> get props => [
    streak,
    streakError,
    streakLoading,
    ownedAreaSqm,
    ownedAreaError,
    ownedAreaLoading,
    squadRank,
    squadRankError,
    squad,
    squadError,
    recentActivity,
    recentActivityError,
    recentActivityLoading,
    wakeUpTaxMultiplier,
  ];
}
