import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/alarm_repository.dart';

class SetAlarmActiveParams extends Equatable {
  const SetAlarmActiveParams({required this.id, required this.isActive});

  final String id;
  final bool isActive;

  @override
  List<Object?> get props => [id, isActive];
}

@injectable
class SetAlarmActive implements UseCase<void, SetAlarmActiveParams> {
  SetAlarmActive(this._repository);

  final AlarmRepository _repository;

  @override
  Future<void> call(SetAlarmActiveParams params) => _repository.setActive(params.id, params.isActive);
}
