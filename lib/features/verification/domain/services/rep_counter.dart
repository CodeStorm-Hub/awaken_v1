import '../entities/body_pose.dart';
import 'joint_angle.dart';

enum RepPhase { up, down }

/// Feeds one [BodyPose] at a time; a rep is counted on the down→up
/// transition (bottom of the squat / push-up reached, then returned to the
/// starting position) so a partial rep never counts.
abstract interface class RepCounter {
  /// Returns true if this pose completed a rep.
  bool update(BodyPose pose);

  RepPhase get phase;

  /// The joint angle at the most recent rep confirmation (the frame
  /// `update()` last returned `true` for) — null before any rep has been
  /// confirmed. Used to build the rep-evidence trace submitted for
  /// server-side plausibility validation; not consumed by the state
  /// machine itself.
  double? get lastConfirmedAngleDegrees;

  void reset();
}

/// Joint-angle-based rep state machine (plan §6 Phase 2: "joint-angle rep
/// state machine (squat first, then push-up)"). Parameterized by a
/// left/right joint-chain pair and down/up angle thresholds so squat and
/// push-up are the same algorithm over different joints.
class AngleRepCounter implements RepCounter {
  AngleRepCounter({
    required this.leftChain,
    required this.rightChain,
    required this.downThresholdDegrees,
    required this.upThresholdDegrees,
  });

  /// Squat: hip→knee→ankle. Down when the knee angle drops below ~100°
  /// (thighs approaching parallel to the ground), up when it straightens
  /// back out past ~160°. Thresholds intentionally leave a dead zone
  /// between 100° and 160° so noisy frames near either boundary don't
  /// flicker the phase.
  factory AngleRepCounter.squat() => AngleRepCounter(
    leftChain: const JointChain(
      proximal: BodyJoint.leftHip,
      vertex: BodyJoint.leftKnee,
      distal: BodyJoint.leftAnkle,
    ),
    rightChain: const JointChain(
      proximal: BodyJoint.rightHip,
      vertex: BodyJoint.rightKnee,
      distal: BodyJoint.rightAnkle,
    ),
    downThresholdDegrees: 100,
    upThresholdDegrees: 160,
  );

  /// Push-up: shoulder→elbow→wrist, same dead-zone reasoning as squat.
  factory AngleRepCounter.pushup() => AngleRepCounter(
    leftChain: const JointChain(
      proximal: BodyJoint.leftShoulder,
      vertex: BodyJoint.leftElbow,
      distal: BodyJoint.leftWrist,
    ),
    rightChain: const JointChain(
      proximal: BodyJoint.rightShoulder,
      vertex: BodyJoint.rightElbow,
      distal: BodyJoint.rightWrist,
    ),
    downThresholdDegrees: 90,
    upThresholdDegrees: 160,
  );

  final JointChain leftChain;
  final JointChain rightChain;
  final double downThresholdDegrees;
  final double upThresholdDegrees;

  /// Frames a threshold crossing must hold before the phase actually
  /// transitions — a single noisy frame (a bad landmark estimate spiking
  /// the angle for one sample) no longer flips the phase by itself.
  static const _confirmFrames = 2;

  /// Minimum frames spent in [RepPhase.down] before an up-crossing is
  /// allowed to count as a completed rep — rejects a fast bounce that dips
  /// past the down threshold and springs straight back up in the same
  /// couple of frames, which isn't a real rep at depth.
  static const _minDownFrames = 2;

  /// Frames to ignore a fresh down-crossing immediately after counting a
  /// rep — guards against angle jitter right at the up threshold
  /// oscillating back below the down threshold and starting a spurious
  /// second rep a frame or two later.
  static const _cooldownFrames = 3;

  @override
  RepPhase phase = RepPhase.up;

  @override
  double? lastConfirmedAngleDegrees;

  int _belowStreak = 0;
  int _aboveStreak = 0;
  int _downHoldFrames = 0;
  int _cooldownRemaining = 0;

  /// Which side is being used for the rep currently in progress, `null`
  /// when neutral (no descent started). Locked the moment a descent begins
  /// so a user can't complete one rep by switching sides mid-way — e.g.
  /// dipping the left knee for the confirm frames, then straightening the
  /// right leg for the up-crossing, without either side alone ever
  /// completing a real rep.
  bool? _lockedIsLeft;

  @override
  void reset() {
    phase = RepPhase.up;
    _belowStreak = 0;
    _aboveStreak = 0;
    _downHoldFrames = 0;
    _cooldownRemaining = 0;
    _lockedIsLeft = null;
    lastConfirmedAngleDegrees = null;
  }

  @override
  bool update(BodyPose pose) {
    final left = _chainAngle(pose, leftChain);
    final right = _chainAngle(pose, rightChain);
    final selected = _selectSide(left, right);
    // A single frame with unusable landmarks shouldn't reset streaks
    // already in progress — occlusion/motion blur on one frame is normal
    // and the next good frame should be able to continue the count.
    if (selected == null) return false;
    final (isLeft, angle) = selected;

    if (_cooldownRemaining > 0) _cooldownRemaining--;

    _belowStreak = angle < downThresholdDegrees ? _belowStreak + 1 : 0;
    _aboveStreak = angle > upThresholdDegrees ? _aboveStreak + 1 : 0;

    // Lock in the side driving this descent as soon as it starts; release
    // the lock once fully back to neutral so the next rep can re-pick
    // whichever side reads clearer.
    if (_belowStreak >= 1) {
      _lockedIsLeft ??= isLeft;
    } else if (phase == RepPhase.up) {
      _lockedIsLeft = null;
    }

    if (phase == RepPhase.up) {
      if (_belowStreak >= _confirmFrames && _cooldownRemaining == 0) {
        phase = RepPhase.down;
        _downHoldFrames = 0;
      }
      return false;
    }

    // phase == RepPhase.down
    _downHoldFrames++;
    if (_aboveStreak >= _confirmFrames && _downHoldFrames >= _minDownFrames) {
      phase = RepPhase.up;
      _cooldownRemaining = _cooldownFrames;
      _belowStreak = 0;
      _aboveStreak = 0;
      _lockedIsLeft = null;
      lastConfirmedAngleDegrees = angle;
      return true;
    }
    return false;
  }

  /// While a rep is locked to one side, only that side's chain is used
  /// (returning null if it's unavailable this frame, rather than falling
  /// back to the other side). While neutral, picks whichever side has
  /// higher combined landmark confidence — the user is typically angled
  /// toward the camera such that one side is clearer than the other.
  (bool isLeft, double angle)? _selectSide(
    ({double angle, double confidence})? left,
    ({double angle, double confidence})? right,
  ) {
    final locked = _lockedIsLeft;
    if (locked != null) {
      final side = locked ? left : right;
      return side == null ? null : (locked, side.angle);
    }
    if (left == null) return right == null ? null : (false, right.angle);
    if (right == null) return (true, left.angle);
    return left.confidence >= right.confidence
        ? (true, left.angle)
        : (false, right.angle);
  }

  ({double angle, double confidence})? _chainAngle(
    BodyPose pose,
    JointChain chain,
  ) {
    final a = pose[chain.proximal];
    final v = pose[chain.vertex];
    final c = pose[chain.distal];
    if (a == null || v == null || c == null) return null;
    final confidence = (a.likelihood + v.likelihood + c.likelihood) / 3;
    return (angle: jointAngleDegrees(a, v, c), confidence: confidence);
  }
}
