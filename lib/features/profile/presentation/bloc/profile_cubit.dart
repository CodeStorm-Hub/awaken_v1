import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../alarm/domain/usecases/watch_current_streak.dart';
import '../../../territory/domain/usecases/watch_owned_area.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/watch_current_user.dart';
import 'profile_state.dart';

/// Per-page Cubit (like `HomeCubit`/`SquadCubit`), created fresh each time
/// `ProfilePage` opens. Only the stream-based reads live here — the
/// one-shot actions (`SignOut`, `DeleteAccount`, `LinkWithEmail`, etc.)
/// stay as direct `getIt` calls at their dialog call sites, same as
/// `SquadCubit` keeps its own mutation methods separate from the streams
/// it centralizes.
@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(
    this._watchCurrentStreak,
    this._watchOwnedArea,
    this._watchCurrentUser,
  ) : super(const ProfileState()) {
    _streakSub = _watchCurrentStreak().listen(
      (v) => emit(state.copyWith(streak: v, streakError: false)),
      onError: (_) => emit(state.copyWith(streakError: true)),
    );
    _areaSub = _watchOwnedArea().listen(
      (v) => emit(state.copyWith(ownedAreaSqm: v, ownedAreaError: false)),
      onError: (_) => emit(state.copyWith(ownedAreaError: true)),
    );
    _userSub = _watchCurrentUser().listen(
      (v) => emit(
        v == null ? state.copyWith(clearUser: true) : state.copyWith(user: v),
      ),
    );
  }

  final WatchCurrentStreak _watchCurrentStreak;
  final WatchOwnedArea _watchOwnedArea;
  final WatchCurrentUser _watchCurrentUser;

  late final StreamSubscription<int> _streakSub;
  late final StreamSubscription<double> _areaSub;
  late final StreamSubscription<AppUser?> _userSub;

  @override
  Future<void> close() async {
    await _streakSub.cancel();
    await _areaSub.cancel();
    await _userSub.cancel();
    return super.close();
  }
}
