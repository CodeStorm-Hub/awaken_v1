import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

/// Phase 1 scope: raw dismiss, not yet gated by exercise verification
/// (verification gating lands in Phase 4 — plan §6).
@injectable
class DismissAlarm implements UseCase<void, String> {
  DismissAlarm(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(String params) => _repository.dismissAlarm(params);
}
