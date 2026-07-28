import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_presence_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../../domain/usecases/create_squad.dart';
import '../../domain/usecases/join_squad.dart';
import '../../domain/usecases/leave_squad.dart';
import '../../domain/usecases/watch_leaderboard.dart';
import '../../domain/usecases/watch_my_squad.dart';
import '../../domain/usecases/watch_squad_presence.dart';
import '../squad_error_message.dart';
import 'squad_state.dart';

/// Per-page Cubit (like `RunTrackingCubit`/`VerificationCubit`), created
/// fresh each time `SquadPage` opens.
@injectable
class SquadCubit extends Cubit<SquadState> {
  SquadCubit(
    this._watchMySquad,
    this._createSquad,
    this._joinSquad,
    this._leaveSquad,
    this._watchLeaderboard,
    this._watchSquadPresence,
    this._squadRepository,
  ) : super(const SquadState()) {
    _subscribeToMySquad();
  }

  void _subscribeToMySquad() {
    // `SquadStatus.error` is reserved for a genuine failure of this stream
    // itself (e.g. a dropped realtime connection) — not for a failed
    // create/join action, which must not blow away whatever the user was
    // already looking at. See `createSquad`/`joinSquad` below.
    _mySquadSub = _watchMySquad().listen(
      _onSquadChanged,
      onError: (Object e) => emit(
        state.copyWith(
          status: SquadStatus.error,
          errorMessage: friendlySquadErrorMessage(e),
        ),
      ),
    );
  }

  /// Re-subscribes after a genuine stream failure (`SquadStatus.error`) —
  /// the retry action on `_SquadErrorView`.
  Future<void> retry() async {
    await _mySquadSub.cancel();
    emit(state.copyWith(status: SquadStatus.loading));
    _subscribeToMySquad();
  }

  final WatchMySquad _watchMySquad;
  final CreateSquad _createSquad;
  final JoinSquad _joinSquad;
  final LeaveSquad _leaveSquad;
  final WatchLeaderboard _watchLeaderboard;
  final WatchSquadPresence _watchSquadPresence;
  final SquadRepository _squadRepository;

  // Not `final` — `retry()` cancels and replaces it after a genuine stream
  // failure.
  late StreamSubscription<Squad?> _mySquadSub;
  StreamSubscription<List<LeaderboardEntry>>? _leaderboardSub;
  StreamSubscription<List<SquadPresenceMember>>? _presenceSub;

  void _onSquadChanged(Squad? squad) {
    unawaited(_leaderboardSub?.cancel());
    unawaited(_presenceSub?.cancel());

    if (squad == null) {
      emit(state.copyWith(status: SquadStatus.noSquad, clearSquad: true));
      return;
    }

    emit(state.copyWith(status: SquadStatus.loaded, squad: squad));
    _leaderboardSub = _watchLeaderboard(
      squad.id,
    ).listen((entries) => emit(state.copyWith(leaderboard: entries)));
    _presenceSub = _watchSquadPresence(
      squad.id,
    ).listen((members) => emit(state.copyWith(presence: members)));
  }

  /// Rethrows on failure (instead of flipping `status` to `error`, as this
  /// used to) so a bad squad name just surfaces a SnackBar over the still-
  /// current `noSquad` view — the page keeps both "Create"/"Join" actions
  /// live. Previously a failed create/join stranded the user on the generic
  /// error screen, whose only action re-opened *this same* create dialog —
  /// there was no way back to "Join with invite code" from there.
  Future<void> createSquad(String name) => _createSquad(name);

  /// See [createSquad] — same rationale.
  Future<void> joinSquad(String inviteCode) => _joinSquad(inviteCode);

  /// Previously fire-and-forget with no confirmation, loading, or error
  /// handling — a failure here (e.g. a dropped connection mid-request)
  /// silently left the button looking like it did nothing. Rethrows on
  /// failure so the page can surface it as a SnackBar without disturbing
  /// the still-current `loaded` squad view.
  Future<void> leaveSquad() async {
    emit(state.copyWith(isLeavingSquad: true));
    try {
      await _leaveSquad(const NoParams());
    } catch (e) {
      emit(state.copyWith(isLeavingSquad: false));
      rethrow;
    }
    emit(state.copyWith(isLeavingSquad: false));
  }

  Future<void> reportMember({
    required String reportedUserId,
    required String reason,
  }) {
    return _squadRepository.reportMember(
      reportedUserId: reportedUserId,
      reason: reason,
    );
  }

  @override
  Future<void> close() async {
    await _mySquadSub.cancel();
    await _leaderboardSub?.cancel();
    await _presenceSub?.cancel();
    return super.close();
  }
}
