import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../squad/domain/repositories/squad_repository.dart';
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
  RunTrackingCubit(this._startRun, this._abandonRun, this._captureRun, this._watchRunState, this._squadRepository)
      : super(const RunTrackState());

  final StartRun _startRun;
  final AbandonRun _abandonRun;
  final CaptureRun _captureRun;
  final WatchRunState _watchRunState;

  /// Squad-telemetry broadcast (plan §6 Phase 6, H6) — throttled and a
  /// no-op internally when the user has no squad, so this cubit behaves
  /// identically for users outside a squad.
  final SquadRepository _squadRepository;

  Future<void> begin() async {
    _watchRunState().listen((state) {
      emit(state);
      if (state.isTracking) {
        final km = (state.distanceMeters / 1000).toStringAsFixed(1);
        _squadRepository.broadcastTelemetry(label: 'Running · $km km');
      }
    });
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
