import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../../squad/domain/repositories/squad_repository.dart';
import '../../domain/entities/verification_state.dart';
import '../../domain/usecases/start_verification_session.dart';
import '../../domain/usecases/stop_verification_session.dart';
import '../../domain/usecases/watch_verification_state.dart';

/// Per-session Cubit (not app-wide like `AlarmCubit`) — created fresh each
/// time `VerificationPage` opens and disposed with it, since a pose
/// verification session is scoped to one workout, not the whole app
/// lifetime.
@injectable
class VerificationCubit extends Cubit<VerificationState> {
  VerificationCubit(this._startSession, this._stopSession, this._watchState, this._squadRepository)
    : super(const VerificationState());

  final StartVerificationSession _startSession;
  final StopVerificationSession _stopSession;
  final WatchVerificationState _watchState;

  /// Squad-telemetry broadcast (plan §6 Phase 6, H6) — throttled and a
  /// no-op internally when the user has no squad.
  final SquadRepository _squadRepository;

  Future<void> begin({required ExerciseMode exercise, required int targetReps}) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      emit(state.copyWith(status: VerificationStatus.permissionDenied));
      return;
    }

    await WakelockPlus.enable();
    _watchState().listen((state) {
      emit(state);
      if (state.status == VerificationStatus.counting || state.status == VerificationStatus.calibrating) {
        final label = state.exerciseMode == ExerciseMode.squat ? 'squats' : 'push-ups';
        _squadRepository.broadcastTelemetry(label: 'Workout · ${state.completedReps}/${state.targetReps} $label');
      }
    });
    await _startSession(StartVerificationParams(exercise: exercise, targetReps: targetReps));
  }

  @override
  Future<void> close() async {
    await _stopSession(const NoParams());
    await WakelockPlus.disable();
    return super.close();
  }
}
