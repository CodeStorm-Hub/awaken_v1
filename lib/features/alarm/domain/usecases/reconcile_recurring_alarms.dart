import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

/// Self-heal for recurring alarms — call once on app launch (plan
/// discussion: the "hybrid" rescheduling approach's backstop for a missed
/// post-ring reschedule).
@injectable
class ReconcileRecurringAlarms implements UseCase<void, NoParams> {
  ReconcileRecurringAlarms(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.reconcileRecurringAlarms();
}
