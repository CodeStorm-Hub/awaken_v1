import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';

/// Wraps `package:camera` — the only place besides `camera_preview_source`
/// (presentation) that touches it directly. Android-only per the app's
/// scope; always opens the front camera (the user is holding/propping the
/// phone to see their own reps).
@lazySingleton
class CameraDataSource {
  CameraController? _controller;

  /// Exposed for `CameraPreview(controller)` in the presentation layer.
  /// This is a narrow, deliberate exception to "presentation never touches
  /// a plugin directly" — a live camera preview widget needs the actual
  /// `CameraController` handle, and funnelling it through this single
  /// lazySingleton keeps that access to one seam instead of scattering
  /// `package:camera` imports across pages.
  CameraController? get controller => _controller;

  Future<void> startFrontCameraStream(void Function(CameraImage image) onFrame) async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _controller = controller;

    await controller.initialize();
    await controller.startImageStream(onFrame);
  }

  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }
}
