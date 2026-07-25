import 'package:equatable/equatable.dart';

/// Outcome of submitting a captured run to `submit_run()` (plan §3 — server
/// returns the delta for the celebration UI). `pending` means the run was
/// saved locally and queued in the outbox but hasn't reached the server yet
/// (offline at capture time) — the celebration UI should show a "syncing"
/// state rather than a fabricated area.
class RunCaptureResult extends Equatable {
  const RunCaptureResult({
    required this.pending,
    this.accepted,
    this.closedLoop = false,
    this.capturedAreaSqm,
    this.territoryAreaSqm,
    this.bonusAreaSqm,
    this.bountyMultiplier,
    this.rejectedReason,
  });

  const RunCaptureResult.pending()
    : pending = true,
      accepted = null,
      closedLoop = false,
      capturedAreaSqm = null,
      territoryAreaSqm = null,
      bonusAreaSqm = null,
      bountyMultiplier = null,
      rejectedReason = null;

  final bool pending;
  final bool? accepted;
  final bool closedLoop;
  final double? capturedAreaSqm;
  final double? territoryAreaSqm;

  /// Bounty-zone bonus (celebration-UI-only credit — see `Runs` table's
  /// doc comment on these two columns). Null/zero when no active bounty
  /// zone covered this capture.
  final double? bonusAreaSqm;
  final double? bountyMultiplier;
  final String? rejectedReason;

  @override
  List<Object?> get props => [
    pending,
    accepted,
    closedLoop,
    capturedAreaSqm,
    territoryAreaSqm,
    bonusAreaSqm,
    bountyMultiplier,
    rejectedReason,
  ];
}
