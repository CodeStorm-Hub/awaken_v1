import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/platform/system_capabilities.dart';
import '../../domain/repositories/battery_exemption_repository.dart';

@LazySingleton(as: BatteryExemptionRepository)
class BatteryExemptionRepositoryImpl implements BatteryExemptionRepository {
  BatteryExemptionRepositoryImpl(this._systemCapabilities);

  final SystemCapabilities _systemCapabilities;

  /// Manufacturers documented by dontkillmyapp.com as aggressively killing
  /// background apps beyond stock Android Doze (plan H4).
  static const _aggressiveOems = {
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'vivo',
    'huawei',
    'honor',
    'samsung',
    'oneplus',
    'meizu',
    'asus',
  };

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Future<String> getManufacturer() async {
    final manufacturer = await _systemCapabilities.getManufacturer();
    return manufacturer.toLowerCase();
  }

  @override
  bool isAggressiveOem(String manufacturer) => _aggressiveOems.contains(manufacturer);

  @override
  Future<bool> openOemAutostartSettings() => _systemCapabilities.openOemAutostartSettings();
}
