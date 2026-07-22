import '../entities/recent_activity_entry.dart';

abstract interface class HomeActivityRepository {
  /// Most recent [limit] activity entries (verified alarm dismissals +
  /// captured territory), newest first.
  Stream<List<RecentActivityEntry>> watchRecentActivity({int limit = 3});
}
