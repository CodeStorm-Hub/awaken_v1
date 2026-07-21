import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Wraps the native `com.awaken.awaken/system_capabilities` MethodChannel
/// (see android/app/.../MainActivity.kt) — FSI/exact-alarm capability
/// checks and OEM battery-exemption deep links that neither the `alarm`
/// package nor `permission_handler` cover (plan C6, H4).
@lazySingleton
class SystemCapabilities {
  static const _channel = MethodChannel('com.awaken.awaken/system_capabilities');

  Future<bool> canUseFullScreenIntent() async {
    final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    return result ?? false;
  }

  /// Opens Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT. Returns
  /// whether the settings screen was actually launched.
  Future<bool> openFullScreenIntentSettings() async {
    final result = await _channel.invokeMethod<bool>('openFullScreenIntentSettings');
    return result ?? false;
  }

  Future<bool> canScheduleExactAlarms() async {
    final result = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    return result ?? false;
  }

  /// Opens Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM. Returns whether
  /// the settings screen was actually launched.
  Future<bool> openExactAlarmSettings() async {
    final result = await _channel.invokeMethod<bool>('openExactAlarmSettings');
    return result ?? false;
  }

  Future<String> getManufacturer() async {
    final result = await _channel.invokeMethod<String>('getManufacturer');
    return result ?? 'unknown';
  }

  /// Best-effort deep link into a known aggressive-OEM autostart screen.
  /// Returns whether one was found and launched — callers should fall back
  /// to the universal ignore-battery-optimizations request regardless.
  Future<bool> openOemAutostartSettings() async {
    final result = await _channel.invokeMethod<bool>('openOemAutostartSettings');
    return result ?? false;
  }
}
