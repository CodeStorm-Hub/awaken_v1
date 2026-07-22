import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import 'package:awaken/features/verification/data/mappers/pose_mapper.dart';

void main() {
  group('mlkitFormatFor', () {
    test('maps nv21 (Android)', () {
      expect(mlkitFormatFor(ImageFormatGroup.nv21), InputImageFormat.nv21);
    });

    test('maps bgra8888 (iOS)', () {
      expect(mlkitFormatFor(ImageFormatGroup.bgra8888), InputImageFormat.bgra8888);
    });

    test('maps yuv420', () {
      expect(mlkitFormatFor(ImageFormatGroup.yuv420), InputImageFormat.yuv420);
    });

    test('returns null for unsupported formats rather than guessing', () {
      expect(mlkitFormatFor(ImageFormatGroup.jpeg), isNull);
      expect(mlkitFormatFor(ImageFormatGroup.unknown), isNull);
    });
  });
}
