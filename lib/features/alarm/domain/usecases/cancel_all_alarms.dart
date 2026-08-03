import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

/// Used only from account sign-out/switch/delete — see
/// `AlarmRepository.cancelAllAlarms`'s doc comment.
@injectable
class CancelAllAlarms implements UseCase<void, NoParams> {
  CancelAllAlarms(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.cancelAllAlarms();
}
