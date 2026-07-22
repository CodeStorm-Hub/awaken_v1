import 'package:injectable/injectable.dart';

import '../entities/recent_activity_entry.dart';
import '../repositories/home_activity_repository.dart';

@injectable
class WatchRecentActivity {
  WatchRecentActivity(this._repository);

  final HomeActivityRepository _repository;

  Stream<List<RecentActivityEntry>> call({int limit = 3}) =>
      _repository.watchRecentActivity(limit: limit);
}
