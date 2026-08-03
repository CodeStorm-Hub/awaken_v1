import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/battery_exemption_status.dart';
import '../repositories/battery_exemption_repository.dart';

@injectable
class CheckBatteryExemptionStatus
    implements UseCase<BatteryExemptionStatus, NoParams> {
  CheckBatteryExemptionStatus(this._repository);

  final BatteryExemptionRepository _repository;

  @override
  Future<BatteryExemptionStatus> call(NoParams params) async {
    final manufacturer = await _repository.getManufacturer();
    return BatteryExemptionStatus(
      isExempt: await _repository.isIgnoringBatteryOptimizations(),
      manufacturer: manufacturer,
      isAggressiveOem: _repository.isAggressiveOem(manufacturer),
    );
  }
}
