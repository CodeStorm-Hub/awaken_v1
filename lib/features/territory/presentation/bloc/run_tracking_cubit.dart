import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/run_capture_result.dart';
import '../../domain/entities/run_track_state.dart';
import '../../domain/usecases/abandon_run.dart';
import '../../domain/usecases/capture_run.dart';
import '../../domain/usecases/start_run.dart';
import '../../domain/usecases/watch_run_state.dart';

/// Per-session Cubit (not app-wide) — created fresh each time
/// `ActiveRunPage` opens, matching `VerificationCubit`'s scoping rationale:
/// a run is scoped to one tracking session, not the app lifetime.
@injectable
class RunTrackingCubit extends Cubit<RunTrackState> {
  RunTrackingCubit(this._startRun, this._abandonRun, this._captureRun, this._watchRunState)
      : super(const RunTrackState());

  final StartRun _startRun;
  final AbandonRun _abandonRun;
  final CaptureRun _captureRun;
  final WatchRunState _watchRunState;

  Future<void> begin() async {
    _watchRunState().listen(emit);
    await _startRun(const NoParams());
  }

  Future<void> abandon() => _abandonRun(const NoParams());

  Future<RunCaptureResult> capture() => _captureRun(const NoParams());

  @override
  Future<void> close() async {
    if (state.isTracking) {
      await _abandonRun(const NoParams());
    }
    return super.close();
  }
}
