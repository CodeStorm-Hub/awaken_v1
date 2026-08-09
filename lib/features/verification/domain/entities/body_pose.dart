import 'package:equatable/equatable.dart';

/// Joints needed for squat/push-up angle math. Deliberately a small,
/// domain-owned enum rather than exposing google_mlkit_pose_detection's
/// `PoseLandmarkType` outside the data layer (mapping lives in
/// `data/mappers/pose_mapper.dart`).
enum BodyJoint {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class JointPosition extends Equatable {
  const JointPosition({
    required this.x,
    required this.y,
    required this.likelihood,
  });

  final double x;
  final double y;

  /// ML Kit's per-landmark confidence (0.0–1.0). Used to pick which body
  /// side (left/right) is more reliably visible to the camera and to
  /// detect "no usable pose" (low-light / out-of-frame) conditions.
  final double likelihood;

  @override
  List<Object?> get props => [x, y, likelihood];
}

class BodyPose extends Equatable {
  const BodyPose({required this.joints});

  final Map<BodyJoint, JointPosition> joints;

  JointPosition? operator [](BodyJoint joint) => joints[joint];

  /// Mean landmark confidence across all detected joints — a proxy for
  /// "is this frame usable" (low light, partial occlusion, out of frame).
  double get averageLikelihood {
    if (joints.isEmpty) return 0;
    final sum = joints.values.fold<double>(0, (acc, j) => acc + j.likelihood);
    return sum / joints.length;
  }

  @override
  List<Object?> get props => [joints];
}
