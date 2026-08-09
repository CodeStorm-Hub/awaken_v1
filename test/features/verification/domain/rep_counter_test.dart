import 'package:flutter_test/flutter_test.dart';

import 'package:awaken/features/verification/domain/entities/body_pose.dart';
import 'package:awaken/features/verification/domain/services/joint_angle.dart';
import 'package:awaken/features/verification/domain/services/rep_counter.dart';

BodyPose _twoSidedSquatPose({
  required double leftKneeAngleHint,
  required double rightKneeAngleHint,
  double leftLikelihood = 1,
  double rightLikelihood = 1,
}) {
  final leftKnee = JointPosition(
    x: leftKneeAngleHint,
    y: 1,
    likelihood: leftLikelihood,
  );
  final rightKnee = JointPosition(
    x: rightKneeAngleHint,
    y: 1,
    likelihood: rightLikelihood,
  );
  return BodyPose(
    joints: {
      BodyJoint.leftHip: JointPosition(x: 0, y: 0, likelihood: leftLikelihood),
      BodyJoint.leftKnee: leftKnee,
      BodyJoint.leftAnkle: JointPosition(x: 0, y: 2, likelihood: leftLikelihood),
      BodyJoint.rightHip: JointPosition(x: 0, y: 0, likelihood: rightLikelihood),
      BodyJoint.rightKnee: rightKnee,
      BodyJoint.rightAnkle: JointPosition(x: 0, y: 2, likelihood: rightLikelihood),
    },
  );
}

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

/// Feeds [count] identical frames and returns how many counted as a
/// completed rep — the rep counter now requires several consecutive
/// confirming frames (noise rejection), not a single threshold crossing.
int _feed(AngleRepCounter counter, double kneeAngleHint, int count) {
  var reps = 0;
  for (var i = 0; i < count; i++) {
    if (counter.update(_squatPose(kneeAngleHint: kneeAngleHint))) reps++;
  }
  return reps;
}

int _feed2(
  AngleRepCounter counter,
  int count, {
  required double leftKneeAngleHint,
  required double rightKneeAngleHint,
  double leftLikelihood = 1,
  double rightLikelihood = 1,
}) {
  var reps = 0;
  for (var i = 0; i < count; i++) {
    if (counter.update(
      _twoSidedSquatPose(
        leftKneeAngleHint: leftKneeAngleHint,
        rightKneeAngleHint: rightKneeAngleHint,
        leftLikelihood: leftLikelihood,
        rightLikelihood: rightLikelihood,
      ),
    )) {
      reps++;
    }
  }
  return reps;
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
    test('down-then-up transition counts exactly one rep once confirmed', () {
      final counter = AngleRepCounter.squat();

      expect(_feed(counter, 0, 1), 0); // stays up
      expect(counter.phase, RepPhase.up);

      expect(_feed(counter, 1, 2), 0); // 2 confirming down frames
      expect(counter.phase, RepPhase.down);

      expect(_feed(counter, 0, 2), 1); // 2 confirming up frames: 1 rep
      expect(counter.phase, RepPhase.up);
    });

    test('a single noisy frame below the down threshold does not flip the phase', () {
      final counter = AngleRepCounter.squat();
      expect(counter.update(_squatPose(kneeAngleHint: 1)), isFalse); // only 1 confirming frame
      expect(counter.phase, RepPhase.up); // needs 2 to confirm
    });

    test('a single above-threshold frame after going down does not immediately complete the rep', () {
      final counter = AngleRepCounter.squat();
      expect(_feed(counter, 1, 2), 0); // confirm down
      expect(counter.phase, RepPhase.down);
      expect(counter.update(_squatPose(kneeAngleHint: 0)), isFalse); // only 1 confirming up frame
      expect(counter.phase, RepPhase.down); // needs 2 to confirm
    });

    test('cooldown after a rep delays the next down-transition beyond confirmFrames alone', () {
      final counter = AngleRepCounter.squat();
      expect(_feed(counter, 1, 2), 0);
      expect(_feed(counter, 0, 2), 1); // 1 rep, 3-frame cooldown now active

      // Below-threshold streak alone would confirm after 2 frames
      // (confirmFrames), but the 3-frame cooldown blocks the transition
      // until the 3rd.
      expect(counter.update(_squatPose(kneeAngleHint: 1)), isFalse);
      expect(counter.phase, RepPhase.up);
      expect(counter.update(_squatPose(kneeAngleHint: 1)), isFalse);
      expect(counter.phase, RepPhase.up); // still blocked
      expect(counter.update(_squatPose(kneeAngleHint: 1)), isFalse);
      expect(counter.phase, RepPhase.down); // cooldown elapsed — now transitions

      expect(_feed(counter, 0, 2), 1); // and a second rep counts normally
    });

    test('does not count a rep that never reaches the down threshold', () {
      final counter = AngleRepCounter.squat();

      // A shallow partial bend that never crosses the 100° down threshold.
      expect(_feed(counter, 0.3, 2), 0);
      expect(_feed(counter, 0, 2), 0);
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
      _feed(counter, 1, 2);
      expect(counter.phase, RepPhase.down);
      counter.reset();
      expect(counter.phase, RepPhase.up);
    });

    test(
      'switching to a higher-confidence straight side mid-descent does not '
      'complete a rep without the locked side also straightening',
      () {
        final counter = AngleRepCounter.squat();

        // Descend on the left leg only; confirm the down phase.
        expect(
          _feed2(
            counter,
            2,
            leftKneeAngleHint: 1,
            rightKneeAngleHint: 0,
          ),
          0,
        );
        expect(counter.phase, RepPhase.down);

        // Right leg (still straight, i.e. "up") now reports much higher
        // confidence than the bent left leg. Without a side lock,
        // `_bestSideAngle` would switch to the right leg's up-angle and
        // could complete a rep despite the left leg (the one that actually
        // went down) never having straightened back out.
        expect(
          _feed2(
            counter,
            2,
            leftKneeAngleHint: 1,
            rightKneeAngleHint: 0,
            leftLikelihood: 0.3,
            rightLikelihood: 1,
          ),
          0,
        );
        expect(counter.phase, RepPhase.down); // still down: left never rose

        // Only once the locked (left) side actually straightens does the
        // rep complete.
        expect(
          _feed2(
            counter,
            2,
            leftKneeAngleHint: 0,
            rightKneeAngleHint: 0,
          ),
          1,
        );
        expect(counter.phase, RepPhase.up);
      },
    );

    test('two full reps count twice, accounting for the post-rep cooldown', () {
      final counter = AngleRepCounter.squat();
      var reps = 0;
      // down x2, up x2 (rep 1) — then the 3-frame cooldown eats the first 3
      // "down" frames of the second attempt before it's allowed to
      // transition, so 3 down frames (not 2) are needed before the second
      // down x2/up x2 confirms rep 2.
      for (final hint in [1, 1, 0, 0, 1, 1, 1, 0, 0]) {
        if (counter.update(_squatPose(kneeAngleHint: hint.toDouble()))) reps++;
      }
      expect(reps, 2);
    });

    test(
      'lastConfirmedAngleDegrees is null before any rep, then holds the '
      'confirming frame\'s angle after each rep — evidence for the '
      'server-side rep-trace plausibility check',
      () {
        final counter = AngleRepCounter.squat();
        expect(counter.lastConfirmedAngleDegrees, isNull);

        for (final hint in [1, 1, 0, 0]) {
          counter.update(_squatPose(kneeAngleHint: hint.toDouble()));
        }
        expect(counter.lastConfirmedAngleDegrees, isNotNull);
        expect(counter.lastConfirmedAngleDegrees!, greaterThan(counter.upThresholdDegrees));
      },
    );

    test('reset() clears lastConfirmedAngleDegrees back to null', () {
      final counter = AngleRepCounter.squat();
      for (final hint in [1, 1, 0, 0]) {
        counter.update(_squatPose(kneeAngleHint: hint.toDouble()));
      }
      expect(counter.lastConfirmedAngleDegrees, isNotNull);

      counter.reset();

      expect(counter.lastConfirmedAngleDegrees, isNull);
    });
  });

  group('AngleRepCounter.pushup', () {
    test('down-then-up transition counts exactly one rep once confirmed', () {
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
      expect(counter.update(elbowPose(1.2)), isFalse); // 2nd confirming down frame
      expect(counter.phase, RepPhase.down);
      expect(counter.update(elbowPose(0)), isFalse);
      expect(counter.update(elbowPose(0)), isTrue); // 2nd confirming up frame
    });
  });
}
