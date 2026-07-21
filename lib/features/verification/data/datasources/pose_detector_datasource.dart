import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:injectable/injectable.dart';

/// Thin wrapper over `google_mlkit_pose_detection`'s `PoseDetector` — the
/// only place besides `pose_mapper.dart` that touches ML Kit types
/// directly. STREAM mode + base model per plan §6 (accuracy model is for
/// static images, not a live camera feed).
@lazySingleton
class PoseDetectorDataSource {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(model: PoseDetectionModel.base, mode: PoseDetectionMode.stream),
  );

  Future<List<Pose>> process(InputImage image) => _detector.processImage(image);

  Future<void> close() => _detector.close();
}
