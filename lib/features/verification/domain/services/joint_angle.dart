import 'dart:math' as math;

import '../entities/body_pose.dart';

/// Angle at [vertex], between rays to [a] and [c], in degrees (0–180).
/// Standard 2D joint-angle formula used for the squat (hip-knee-ankle) and
/// push-up (shoulder-elbow-wrist) rep state machines.
double jointAngleDegrees(
  JointPosition a,
  JointPosition vertex,
  JointPosition c,
) {
  final v1x = a.x - vertex.x;
  final v1y = a.y - vertex.y;
  final v2x = c.x - vertex.x;
  final v2y = c.y - vertex.y;

  final dot = v1x * v2x + v1y * v2y;
  final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
  final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (mag1 == 0 || mag2 == 0) return 0;

  final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
  return math.acos(cosAngle) * 180 / math.pi;
}

/// A three-joint chain (e.g. hip → knee → ankle) whose middle joint's angle
/// drives a rep count, with a left/right pair so whichever side the camera
/// sees more clearly (higher confidence) is used.
class JointChain {
  const JointChain({
    required this.proximal,
    required this.vertex,
    required this.distal,
  });

  final BodyJoint proximal;
  final BodyJoint vertex;
  final BodyJoint distal;
}
