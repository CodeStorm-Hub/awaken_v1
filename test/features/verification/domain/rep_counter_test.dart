import 'package:flutter_test/flutter_test.dart';

import 'package:awaken/features/verification/domain/entities/body_pose.dart';
import 'package:awaken/features/verification/domain/services/joint_angle.dart';
import 'package:awaken/features/verification/domain/services/rep_counter.dart';

BodyPose _squatPose({required double kneeAngleHint}) {
  // kneeAngleHint controls how far the knee is pushed forward of the
  // hip-ankle line: 0 = straight leg (~180°), 1 = deep bend (~90°).
  final knee = JointPosition(x: kneeAngleHint, y: 1, likelihood: 1);
  return BodyPose(
    joints: {
      BodyJoint.leftHip: const JointPosition(x: 0, y: 0, likelihood: 1),
      BodyJoint.leftKnee: knee,
      BodyJoint.leftAnkle: const JointPosition(x: 0, y: 2, likelihood: 1),
    },
  );
}

void main() {
  group('jointAngleDegrees', () {
    test('straight line is ~180 degrees', () {
      const a = JointPosition(x: 0, y: 0, likelihood: 1);
      const vertex = JointPosition(x: 0, y: 1, likelihood: 1);
      const c = JointPosition(x: 0, y: 2, likelihood: 1);
      expect(jointAngleDegrees(a, vertex, c), closeTo(180, 0.01));
    });

    test('right angle is 90 degrees', () {
      const a = JointPosition(x: 1, y: 0, likelihood: 1);
      const vertex = JointPosition(x: 0, y: 0, likelihood: 1);
      const c = JointPosition(x: 0, y: 1, likelihood: 1);
      expect(jointAngleDegrees(a, vertex, c), closeTo(90, 0.01));
    });

    test('degenerate (coincident) points return 0 rather than NaN', () {
      const a = JointPosition(x: 0, y: 0, likelihood: 1);
      expect(jointAngleDegrees(a, a, a), 0);
    });
  });

  group('AngleRepCounter.squat', () {
    test('down-then-up transition counts exactly one rep', () {
      final counter = AngleRepCounter.squat();

      expect(counter.update(_squatPose(kneeAngleHint: 0)), isFalse); // stays up
      expect(counter.phase, RepPhase.up);

      expect(counter.update(_squatPose(kneeAngleHint: 1)), isFalse); // goes down
      expect(counter.phase, RepPhase.down);

      expect(counter.update(_squatPose(kneeAngleHint: 0)), isTrue); // back up: 1 rep
      expect(counter.phase, RepPhase.up);
    });

    test('does not count a rep that never reaches the down threshold', () {
      final counter = AngleRepCounter.squat();

      // A shallow partial bend that never crosses the 100° down threshold.
      expect(counter.update(_squatPose(kneeAngleHint: 0.3)), isFalse);
      expect(counter.update(_squatPose(kneeAngleHint: 0)), isFalse);
      expect(counter.phase, RepPhase.up);
    });

    test('missing landmarks produce no transition', () {
      final counter = AngleRepCounter.squat();
      final emptyPose = const BodyPose(joints: {});
      expect(counter.update(emptyPose), isFalse);
      expect(counter.phase, RepPhase.up);
    });

    test('reset returns to the up phase', () {
      final counter = AngleRepCounter.squat();
      counter.update(_squatPose(kneeAngleHint: 1));
      expect(counter.phase, RepPhase.down);
      counter.reset();
      expect(counter.phase, RepPhase.up);
    });

    test('two full reps count twice', () {
      final counter = AngleRepCounter.squat();
      var reps = 0;
      for (final hint in [1, 0, 1, 0]) {
        if (counter.update(_squatPose(kneeAngleHint: hint.toDouble()))) reps++;
      }
      expect(reps, 2);
    });
  });

  group('AngleRepCounter.pushup', () {
    test('down-then-up transition counts exactly one rep', () {
      final counter = AngleRepCounter.pushup();
      BodyPose elbowPose(double hint) => BodyPose(
        joints: {
          BodyJoint.leftShoulder: const JointPosition(x: 0, y: 0, likelihood: 1),
          BodyJoint.leftElbow: JointPosition(x: hint, y: 1, likelihood: 1),
          BodyJoint.leftWrist: const JointPosition(x: 0, y: 2, likelihood: 1),
        },
      );

      expect(counter.update(elbowPose(0)), isFalse);
      expect(counter.update(elbowPose(1.2)), isFalse);
      expect(counter.phase, RepPhase.down);
      expect(counter.update(elbowPose(0)), isTrue);
    });
  });
}
