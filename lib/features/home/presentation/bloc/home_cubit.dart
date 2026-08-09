import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../sync/pull/pull_down_sync.dart';
import '../../../alarm/data/datasources/wake_up_tax_store.dart';
import '../../../alarm/domain/usecases/watch_current_streak.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/domain/usecases/watch_my_rank.dart';
import '../../../squad/domain/usecases/watch_my_squad.dart';
import '../../../territory/domain/usecases/watch_owned_area.dart';
import '../../domain/entities/recent_activity_entry.dart';
import '../../domain/usecases/watch_recent_activity.dart';
import 'home_state.dart';

/// Per-page Cubit (like `SquadCubit`), created fresh each time `HomePage`
/// opens. `AlarmCubit` (Home's fifth data source — next-alarm) stays
/// app-wide and out of this Cubit, since it's already a singleton every
/// page reads directly; duplicating its subscription here would just be a
/// second copy of the same state.
@injectable
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    this._watchCurrentStreak,
    this._watchOwnedArea,
    this._watchMyRank,
    this._watchMySquad,
    this._watchRecentActivity,
    this._wakeUpTaxStore,
    this._pullDownSync,
  ) : super(const HomeState()) {
    _streakSub = _watchCurrentStreak().listen(
      (v) => emit(
        state.copyWith(streak: v, streakError: false, streakLoading: false),
      ),
      onError: (_) =>
          emit(state.copyWith(streakError: true, streakLoading: false)),
    );
    _areaSub = _watchOwnedArea().listen(
      (v) => emit(
        state.copyWith(
          ownedAreaSqm: v,
          ownedAreaError: false,
          ownedAreaLoading: false,
        ),
      ),
      onError: (_) =>
          emit(state.copyWith(ownedAreaError: true, ownedAreaLoading: false)),
    );
    _rankSub = _watchMyRank().listen(
      (v) => emit(
        v == null
            ? state.copyWith(clearSquadRank: true, squadRankError: false)
            : state.copyWith(squadRank: v, squadRankError: false),
      ),
      onError: (_) => emit(state.copyWith(squadRankError: true)),
    );
    _squadSub = _watchMySquad().listen(
      (v) => emit(
        v == null
            ? state.copyWith(clearSquad: true, squadError: false)
            : state.copyWith(squad: v, squadError: false),
      ),
      onError: (_) => emit(state.copyWith(squadError: true)),
    );
    _activitySub = _watchRecentActivity().listen(
      (v) => emit(
        state.copyWith(
          recentActivity: v,
          recentActivityError: false,
          recentActivityLoading: false,
        ),
      ),
      onError: (_) => emit(
        state.copyWith(recentActivityError: true, recentActivityLoading: false),
      ),
    );
    _taxSub = _wakeUpTaxStore.watch().listen(
      (v) => emit(state.copyWith(wakeUpTaxMultiplier: v)),
    );
  }

  final WatchCurrentStreak _watchCurrentStreak;
  final WatchOwnedArea _watchOwnedArea;
  final WatchMyRank _watchMyRank;
  final WatchMySquad _watchMySquad;
  final WatchRecentActivity _watchRecentActivity;
  final WakeUpTaxStore _wakeUpTaxStore;
  final PullDownSync _pullDownSync;

  late final StreamSubscription<int> _streakSub;
  late final StreamSubscription<double> _areaSub;
  late final StreamSubscription<int?> _rankSub;
  late final StreamSubscription<Squad?> _squadSub;
  late StreamSubscription<List<RecentActivityEntry>> _activitySub;
  late final StreamSubscription<double> _taxSub;

  /// Re-subscribes after `recentActivityError` — previously there was no
  /// way to recover from a failed fetch short of restarting the app,
  /// unlike every error state elsewhere in the app (Squad, Profile's auth
  /// actions), which all offer a retry.
  void retryRecentActivity() {
    unawaited(_activitySub.cancel());
    emit(
      state.copyWith(recentActivityError: false, recentActivityLoading: true),
    );
    _activitySub = _watchRecentActivity().listen(
      (v) => emit(
        state.copyWith(
          recentActivity: v,
          recentActivityError: false,
          recentActivityLoading: false,
        ),
      ),
      onError: (_) => emit(
        state.copyWith(recentActivityError: true, recentActivityLoading: false),
      ),
    );
  }

  /// Backs the page's `RefreshIndicator` — re-runs the same remote→local
  /// delta pull (`PullDownSync.run()`) that bootstrap/`SyncWorker` already
  /// use. The section streams above are live Drift watches, so once the
  /// pull writes fresh rows they update on their own; this just forces an
  /// out-of-band pull instead of waiting for the next connectivity-triggered
  /// `SyncWorker` cycle.
  Future<void> refresh() => _pullDownSync.run();

  @override
  Future<void> close() async {
    await _streakSub.cancel();
    await _areaSub.cancel();
    await _rankSub.cancel();
    await _squadSub.cancel();
    await _activitySub.cancel();
    await _taxSub.cancel();
    return super.close();
  }
}
