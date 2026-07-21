import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/battery_exemption_repository.dart';

@injectable
class RequestBatteryExemption implements UseCase<void, NoParams> {
  RequestBatteryExemption(this._repository);

  final BatteryExemptionRepository _repository;

  @override
  Future<void> call(NoParams params) => _repository.requestIgnoreBatteryOptimizations();
}
