import 'package:equatable/equatable.dart';

class BatteryExemptionStatus extends Equatable {
  const BatteryExemptionStatus({
    required this.isExempt,
    required this.manufacturer,
    required this.isAggressiveOem,
  });

  final bool isExempt;
  final String manufacturer;

  /// True for manufacturers known to kill background apps beyond stock
  /// Android's Doze (Xiaomi/HyperOS, Oppo, Vivo, Huawei, Samsung — plan
  /// H4). Onboarding should show extra guidance when this is true.
  final bool isAggressiveOem;

  @override
  List<Object?> get props => [isExempt, manufacturer, isAggressiveOem];
}
