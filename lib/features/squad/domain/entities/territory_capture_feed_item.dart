import 'package:equatable/equatable.dart';

/// One row of `recent_territory_captures()` — feeds the Squad page's
/// "conquest ticker" activity feed (2026-07-29 UI/UX audit item 9).
class TerritoryCaptureFeedItem extends Equatable {
  const TerritoryCaptureFeedItem({
    required this.captureId,
    required this.winnerId,
    required this.winnerDisplayName,
    required this.loserId,
    required this.loserDisplayName,
    required this.areaTakenSqm,
    required this.createdAt,
  });

  final String captureId;
  final String winnerId;
  final String winnerDisplayName;

  /// Null when the capture was of unclaimed land (no rival lost it).
  final String? loserId;
  final String? loserDisplayName;

  final double areaTakenSqm;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    captureId,
    winnerId,
    winnerDisplayName,
    loserId,
    loserDisplayName,
    areaTakenSqm,
    createdAt,
  ];
}
