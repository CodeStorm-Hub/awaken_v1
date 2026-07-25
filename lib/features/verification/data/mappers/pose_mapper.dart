import 'dart:typed_data';
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

/// Maps the camera frame's *actual* reported format to the `InputImageFormat`
/// ML Kit needs. Deliberately reads `image.format.group` at runtime instead
/// of assuming `CameraDataSource`'s requested `ImageFormatGroup` was
/// honored — on iOS, `camera`'s platform implementation only ever reports
/// back `yuv420`/`jpeg`/`bgra8888` regardless of what was requested (verified
/// against `camera_platform_interface`'s own `type_conversion.dart`), and
/// `InputImageFormat.nv21` is Android-only per `google_mlkit_commons`'s own
/// docs — feeding it to iOS's ML Kit build means every frame is
/// misinterpreted and pose detection silently never finds a pose. Returns
/// `null` for anything unsupported so the frame is dropped rather than fed
/// to ML Kit with a wrong/guessed format.
InputImageFormat? mlkitFormatFor(ImageFormatGroup group) => switch (group) {
  ImageFormatGroup.nv21 => InputImageFormat.nv21,
  ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
  ImageFormatGroup.yuv420 => InputImageFormat.yuv420,
  ImageFormatGroup.jpeg || ImageFormatGroup.unknown => null,
};

/// Converts a raw camera frame into the `InputImage` ML Kit's pose detector
/// expects, front-camera rotation-compensated (rotation is ignored on iOS
/// by `google_mlkit_commons` itself — nothing to compensate for there).
InputImage? cameraImageToInputImage(CameraImage image, CameraController controller) {
  final format = mlkitFormatFor(image.format.group);
  if (format == null) return null;

  final sensorOrientation = controller.description.sensorOrientation;
  final deviceOrientationDegrees = _orientationDegrees[controller.value.deviceOrientation] ?? 0;

  final rotationCompensation = controller.description.lensDirection == CameraLensDirection.front
      ? (sensorOrientation + deviceOrientationDegrees) % 360
      : (sensorOrientation - deviceOrientationDegrees + 360) % 360;
  final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  if (rotation == null) return null;

  final bytes = _planeBytesFor(image, format);
  if (bytes == null) return null;

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}

/// `nv21`/`bgra8888` frames arrive as a single plane already containing
/// everything ML Kit needs, so `.first` is correct for those. `yuv420` is
/// genuinely multi-plane (separate Y/U/V buffers) — using only
/// `planes.first` silently drops all chroma data (every frame would be
/// missing U/V), which google_mlkit_commons' own `yuv420` fallback path
/// expects concatenated, not just the luma plane. Returns null if any
/// plane is missing (a malformed/incomplete frame — drop it rather than
/// feed ML Kit a truncated buffer).
Uint8List? _planeBytesFor(CameraImage image, InputImageFormat format) {
  if (format != InputImageFormat.yuv420) {
    return image.planes.first.bytes;
  }
  if (image.planes.length < 3) return null;
  final builder = BytesBuilder(copy: false);
  for (final plane in image.planes) {
    builder.add(plane.bytes);
  }
  return builder.takeBytes();
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
