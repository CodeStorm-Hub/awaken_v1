import 'package:equatable/equatable.dart';

/// One member's live Realtime Presence state within a squad channel — the
/// "Live now" list. `activity` is a short label (e.g. "Running · 2.1 km")
/// kept fresh by throttled `broadcastTelemetry` calls from the active
/// member's own device, per H6's Presence-for-status +
/// Broadcast-for-telemetry split.
class SquadPresenceMember extends Equatable {
  const SquadPresenceMember({
    required this.userId,
    required this.displayName,
    this.activity,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? activity;

  /// Self-asserted in this device's own tracked Presence payload (sourced
  /// from `profiles.avatar_url`) — null for accounts with no linked photo.
  final String? avatarUrl;

  @override
  List<Object?> get props => [userId, displayName, activity, avatarUrl];
}
