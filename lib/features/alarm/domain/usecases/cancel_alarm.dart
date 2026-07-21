import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

@injectable
class CancelAlarm implements UseCase<void, String> {
  CancelAlarm(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(String params) => _repository.cancelAlarm(params);
}
