abstract interface class BatteryExemptionRepository {
  /// True once the OS won't apply Doze/App-Standby battery restrictions to
  /// this app — required for reliable alarm delivery from a killed state
  /// (plan H4).
  Future<bool> isIgnoringBatteryOptimizations();

  /// Shows the standard system dialog
  /// (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS). Works on every OEM.
  Future<void> requestIgnoreBatteryOptimizations();

  /// Device manufacturer (Build.MANUFACTURER), lowercased.
  Future<String> getManufacturer();

  /// True if this manufacturer is known to aggressively kill background
  /// apps beyond stock Android's Doze (dontkillmyapp.com).
  bool isAggressiveOem(String manufacturer);

  /// Best-effort deep link into a known vendor autostart/protected-apps
  /// screen. Returns whether one was found and launched.
  Future<bool> openOemAutostartSettings();
}
