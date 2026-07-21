import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../repositories/battery_exemption_repository.dart';

@injectable
class OpenOemAutostartSettings implements UseCase<bool, NoParams> {
  OpenOemAutostartSettings(this._repository);

  final BatteryExemptionRepository _repository;

  @override
  Future<bool> call(NoParams params) => _repository.openOemAutostartSettings();
}
