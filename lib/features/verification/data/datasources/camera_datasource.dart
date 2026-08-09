import 'dart:io';

import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';

/// Wraps `package:camera` — the only place besides `camera_preview_source`
/// (presentation) that touches it directly. Always opens the front camera
/// (the user is holding/propping the phone to see their own reps).
@lazySingleton
class CameraDataSource {
  CameraController? _controller;

  /// ML Kit's Android build only accepts NV21 (plan H5); its iOS build
  /// never receives NV21 frames at all — `camera`'s iOS implementation
  /// (`camera_platform_interface`'s `type_conversion.dart`) only ever
  /// reports back `yuv420`/`jpeg`/`bgra8888`, regardless of what's
  /// requested here. `pose_mapper.dart`'s `cameraImageToInputImage` reads
  /// the frame's *actual* reported format rather than assuming this
  /// request was honored, so this is a request, not a hard guarantee.
  static final _preferredFormat = Platform.isAndroid
      ? ImageFormatGroup.nv21
      : ImageFormatGroup.bgra8888;

  /// Exposed for `CameraPreview(controller)` in the presentation layer.
  /// This is a narrow, deliberate exception to "presentation never touches
  /// a plugin directly" — a live camera preview widget needs the actual
  /// `CameraController` handle, and funnelling it through this single
  /// lazySingleton keeps that access to one seam instead of scattering
  /// `package:camera` imports across pages.
  CameraController? get controller => _controller;

  Future<void> startFrontCameraStream(
    void Function(CameraImage image) onFrame,
  ) async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: _preferredFormat,
    );

    try {
      await controller.initialize();
      await controller.startImageStream(onFrame);
    } catch (_) {
      // Don't leave a failed, undisposed controller behind — a later
      // retry() would otherwise overwrite `_controller` and leak this one's
      // camera handle/texture resources.
      await controller.dispose();
      rethrow;
    }
    _controller = controller;
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
