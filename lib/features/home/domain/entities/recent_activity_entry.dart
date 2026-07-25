import 'package:equatable/equatable.dart';

enum RecentActivityKind { alarmDismissed, territoryCaptured }

/// One row of the Home page's "Recent activity" feed — replaces the
/// design handoff's hardcoded mock list (which included a "Joined Squad"
/// entry with no backing event data; that kind is deliberately not
/// modeled here since nothing tracks squad-join timestamps yet).
class RecentActivityEntry extends Equatable {
  const RecentActivityEntry({
    required this.kind,
    required this.text,
    required this.occurredAt,
  });

  final RecentActivityKind kind;
  final String text;
  final DateTime occurredAt;

  @override
  List<Object?> get props => [kind, text, occurredAt];
}
