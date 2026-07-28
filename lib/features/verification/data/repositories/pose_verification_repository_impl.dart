import 'dart:async';

import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../alarm/domain/entities/alarm_schedule.dart';
import '../../domain/entities/body_pose.dart';
import '../../domain/entities/verification_state.dart';
import '../../domain/repositories/pose_verification_repository.dart';
import '../../domain/services/rep_counter.dart';
import '../datasources/camera_datasource.dart';
import '../datasources/pose_detector_datasource.dart';
import '../mappers/pose_mapper.dart';

@LazySingleton(as: PoseVerificationRepository)
class PoseVerificationRepositoryImpl implements PoseVerificationRepository {
  PoseVerificationRepositoryImpl(this._camera, this._poseDetector);

  final CameraDataSource _camera;
  final PoseDetectorDataSource _poseDetector;

  final _stateController = StreamController<VerificationState>.broadcast();
  VerificationState _state = const VerificationState();

  RepCounter? _repCounter;

  /// Frame-drop governor (plan §6: "process-latest") — ML Kit inference is
  /// slower than the camera's frame rate, so a new frame is dropped
  /// outright if the previous one is still being processed rather than
  /// queuing up a backlog.
  bool _processingFrame = false;

  /// Explicit processing-FPS ceiling (`AppConstants.targetPoseProcessingFps`
  /// — defined since the plan's original design but never actually
  /// enforced anywhere). `_processingFrame` alone only bounds throughput to
  /// "as fast as ML Kit inference completes" — on a fast device with quick
  /// inference, that can still process/emit well past the intended budget,
  /// driving more `VerificationState` emissions (and therefore widget
  /// rebuilds) than needed. This adds a real minimum-interval gate on top.
  static const _minFrameInterval = Duration(
    milliseconds: 1000 ~/ AppConstants.targetPoseProcessingFps,
  );
  DateTime? _lastProcessedAt;

  /// Bumped on every `start()`/`stop()` — a frame captured just before a
  /// stop/restart can still be mid-flight in `_poseDetector.process()` when
  /// the next session's `start()` resets `_repCounter`/`_state`; without
  /// this check, that straggler's result would land on the *new* session
  /// (e.g. crediting a rep, or resetting calibration) instead of being
  /// discarded as belonging to a session that no longer exists.
  int _generation = 0;

  @override
  Stream<VerificationState> watchState() => _stateController.stream;

  @override
  Future<void> start({required ExerciseMode exercise, required int targetReps}) async {
    _generation++;
    _lastProcessedAt = null;
    _repCounter = exercise == ExerciseMode.squat
        ? AngleRepCounter.squat()
        : AngleRepCounter.pushup();

    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Verification session started',
          category: 'verification',
          data: {'exercise': exercise.name, 'targetReps': targetReps},
        ),
      ),
    );

    try {
      await _camera.startFrontCameraStream(_onFrame);
    } catch (e, st) {
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: st,
          withScope: (scope) => scope
            ..setTag('exercise', exercise.name)
            ..setTag('targetReps', targetReps.toString()),
        ),
      );
      _emit(
        VerificationState(
          status: VerificationStatus.cameraError,
          exerciseMode: exercise,
          targetReps: targetReps,
        ),
      );
      return;
    }

    // Emitted only once the controller is actually initialized — `_CameraView`
    // (verification_page.dart) is a `StatelessWidget` that reads
    // `controller.value.isInitialized` once at build time and never rebuilds
    // on its own; its parent `BlocBuilder` only rebuilds on a `_ViewKind`
    // change (initializing → camera), which is this emit. Emitting
    // `calibrating` before the camera finished starting left `_CameraView`
    // permanently stuck on its inner spinner even after the camera became
    // ready, since no further status change flips viewKind again.
    _emit(
      VerificationState(
        status: VerificationStatus.calibrating,
        exerciseMode: exercise,
        targetReps: targetReps,
      ),
    );
  }

  @override
  Future<void> stop() async {
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: _state.isComplete
              ? 'Verification session completed'
              : 'Verification session ended early',
          category: 'verification',
          data: {
            'exercise': _state.exerciseMode.name,
            'completedReps': _state.completedReps,
            'targetReps': _state.targetReps,
          },
        ),
      ),
    );
    _generation++;
    await _camera.stop();
    _repCounter = null;
    _emit(const VerificationState());
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processingFrame) return;
    final now = DateTime.now();
    final lastProcessedAt = _lastProcessedAt;
    if (lastProcessedAt != null && now.difference(lastProcessedAt) < _minFrameInterval) {
      return;
    }
    final controller = _camera.controller;
    if (controller == null) return;

    final inputImage = cameraImageToInputImage(image, controller);
    if (inputImage == null) return;

    _processingFrame = true;
    _lastProcessedAt = now;
    final generation = _generation;
    try {
      final poses = await _poseDetector.process(inputImage);
      if (generation != _generation) return;
      if (poses.isEmpty) {
        _emit(_state.copyWith(status: VerificationStatus.noPoseDetected, clearPose: true));
        return;
      }

      final pose = poseToBodyPose(poses.first);
      if (pose.averageLikelihood < kMinPoseLikelihood) {
        _emit(_state.copyWith(status: VerificationStatus.noPoseDetected, currentPose: pose));
        return;
      }

      _handleUsablePose(pose);
    } finally {
      _processingFrame = false;
    }
  }

  void _handleUsablePose(BodyPose pose) {
    final counter = _repCounter;
    if (counter == null || _state.isComplete) return;

    final repCompleted = counter.update(pose);

    if (_state.status == VerificationStatus.calibrating) {
      if (!repCompleted) {
        _emit(
          _state.copyWith(
            status: VerificationStatus.calibrating,
            currentPose: pose,
          ),
        );
        return;
      }
      final remaining = _state.calibrationRepsRemaining - 1;
      _emit(
        _state.copyWith(
          status: remaining > 0 ? VerificationStatus.calibrating : VerificationStatus.counting,
          calibrationRepsRemaining: remaining,
          currentPose: pose,
        ),
      );
      return;
    }

    if (!repCompleted) {
      _emit(_state.copyWith(status: VerificationStatus.counting, currentPose: pose));
      return;
    }

    final completed = _state.completedReps + 1;
    final done = completed >= _state.targetReps;
    _emit(
      _state.copyWith(
        status: done ? VerificationStatus.complete : VerificationStatus.counting,
        completedReps: completed,
        currentPose: pose,
      ),
    );
  }

  void _emit(VerificationState state) {
    _state = state;
    _stateController.add(state);
  }
}
