import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;

import '../../domain/entities/body_pose.dart';

/// DeviceOrientation → degrees, used to compensate the sensor's fixed
/// orientation for ML Kit (Android-only; standard boilerplate for this
/// camera+ML Kit combination — see google_mlkit_pose_detection's example).
const _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Converts a raw camera frame (NV21 on Android, per
/// `CameraDataSource`'s `ImageFormatGroup.nv21`) into the `InputImage`
/// ML Kit's pose detector expects, front-camera rotation-compensated.
InputImage? cameraImageToInputImage(CameraImage image, CameraController controller) {
  final sensorOrientation = controller.description.sensorOrientation;
  final deviceOrientationDegrees = _orientationDegrees[controller.value.deviceOrientation] ?? 0;

  final rotationCompensation = controller.description.lensDirection == CameraLensDirection.front
      ? (sensorOrientation + deviceOrientationDegrees) % 360
      : (sensorOrientation - deviceOrientationDegrees + 360) % 360;
  final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  if (rotation == null) return null;

  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

const _landmarkToJoint = {
  mlkit.PoseLandmarkType.leftShoulder: BodyJoint.leftShoulder,
  mlkit.PoseLandmarkType.rightShoulder: BodyJoint.rightShoulder,
  mlkit.PoseLandmarkType.leftElbow: BodyJoint.leftElbow,
  mlkit.PoseLandmarkType.rightElbow: BodyJoint.rightElbow,
  mlkit.PoseLandmarkType.leftWrist: BodyJoint.leftWrist,
  mlkit.PoseLandmarkType.rightWrist: BodyJoint.rightWrist,
  mlkit.PoseLandmarkType.leftHip: BodyJoint.leftHip,
  mlkit.PoseLandmarkType.rightHip: BodyJoint.rightHip,
  mlkit.PoseLandmarkType.leftKnee: BodyJoint.leftKnee,
  mlkit.PoseLandmarkType.rightKnee: BodyJoint.rightKnee,
  mlkit.PoseLandmarkType.leftAnkle: BodyJoint.leftAnkle,
  mlkit.PoseLandmarkType.rightAnkle: BodyJoint.rightAnkle,
};

/// Maps ML Kit's `Pose` (keyed by its own 33-point `PoseLandmarkType`) down
/// to the domain's `BodyPose` (keyed by the ~12 joints the rep counters
/// actually use) — the one place `PoseLandmarkType` is allowed to appear.
BodyPose poseToBodyPose(mlkit.Pose pose) {
  final joints = <BodyJoint, JointPosition>{};
  for (final entry in _landmarkToJoint.entries) {
    final landmark = pose.landmarks[entry.key];
    if (landmark == null) continue;
    joints[entry.value] = JointPosition(
      x: landmark.x,
      y: landmark.y,
      likelihood: landmark.likelihood,
    );
  }
  return BodyPose(joints: joints);
}
