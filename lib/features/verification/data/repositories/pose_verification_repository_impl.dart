import 'dart:async';

import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';

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

  @override
  Stream<VerificationState> watchState() => _stateController.stream;

  @override
  Future<void> start({required ExerciseMode exercise, required int targetReps}) async {
    _repCounter = exercise == ExerciseMode.squat
        ? AngleRepCounter.squat()
        : AngleRepCounter.pushup();
    _emit(
      VerificationState(
        status: VerificationStatus.calibrating,
        exerciseMode: exercise,
        targetReps: targetReps,
      ),
    );

    await _camera.startFrontCameraStream(_onFrame);
  }

  @override
  Future<void> stop() async {
    await _camera.stop();
    _repCounter = null;
    _emit(const VerificationState());
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processingFrame) return;
    final controller = _camera.controller;
    if (controller == null) return;

    final inputImage = cameraImageToInputImage(image, controller);
    if (inputImage == null) return;

    _processingFrame = true;
    try {
      final poses = await _poseDetector.process(inputImage);
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
