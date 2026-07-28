import 'package:flutter/material.dart';

import '../../domain/entities/body_pose.dart';

const _bones = [
  (BodyJoint.leftShoulder, BodyJoint.rightShoulder),
  (BodyJoint.leftShoulder, BodyJoint.leftElbow),
  (BodyJoint.leftElbow, BodyJoint.leftWrist),
  (BodyJoint.rightShoulder, BodyJoint.rightElbow),
  (BodyJoint.rightElbow, BodyJoint.rightWrist),
  (BodyJoint.leftShoulder, BodyJoint.leftHip),
  (BodyJoint.rightShoulder, BodyJoint.rightHip),
  (BodyJoint.leftHip, BodyJoint.rightHip),
  (BodyJoint.leftHip, BodyJoint.leftKnee),
  (BodyJoint.leftKnee, BodyJoint.leftAnkle),
  (BodyJoint.rightHip, BodyJoint.rightKnee),
  (BodyJoint.rightKnee, BodyJoint.rightAnkle),
];

/// Draws joints/bones over the camera preview. `imageSize` is the raw
/// camera frame's pixel size (portrait-swapped — see `VerificationPage`);
/// landmark x/y are scaled from that space into the painted canvas size.
/// Front camera preview is mirrored, so x is flipped to match.
class SkeletonPainter extends CustomPainter {
  const SkeletonPainter({required this.pose, required this.imageSize});

  final BodyPose? pose;
  final Size imageSize;

  static final _bonePaint = Paint()
    ..color = Colors.greenAccent
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke;
  static final _jointPaint = Paint()..color = Colors.greenAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = this.pose;
    if (pose == null || imageSize.width == 0 || imageSize.height == 0) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    Offset project(JointPosition joint) =>
        Offset(size.width - joint.x * scaleX, joint.y * scaleY);

    for (final (a, b) in _bones) {
      final from = pose[a];
      final to = pose[b];
      if (from == null || to == null) continue;
      canvas.drawLine(project(from), project(to), _bonePaint);
    }

    for (final joint in pose.joints.values) {
      canvas.drawCircle(project(joint), 5, _jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      oldDelegate.pose != pose;
}
