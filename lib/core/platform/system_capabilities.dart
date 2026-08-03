import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Wraps the native `com.awaken.awaken/system_capabilities` MethodChannel
/// (see android/app/.../MainActivity.kt) — FSI/exact-alarm capability
/// checks and OEM battery-exemption deep links that neither the `alarm`
/// package nor `permission_handler` cover (plan C6, H4).
///
/// Android-only: there is no iOS implementation of this channel at all.
/// Guarded here at the class level (every method short-circuits to its safe
/// fallback on non-Android platforms) rather than trusting every call site
/// to remember its own `Platform.isAndroid` check — a new caller that
/// forgets one would otherwise hit a `MissingPluginException` on iOS.
@lazySingleton
class SystemCapabilities {
  static const _channel = MethodChannel('com.awaken.awaken/system_capabilities');

  Future<T> _invoke<T>(String method, T fallback) async {
    if (!Platform.isAndroid) return fallback;
    final result = await _channel.invokeMethod<T>(method);
    return result ?? fallback;
  }

  Future<bool> canUseFullScreenIntent() =>
      _invoke('canUseFullScreenIntent', false);

  /// Opens Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT. Returns
  /// whether the settings screen was actually launched.
  Future<bool> openFullScreenIntentSettings() =>
      _invoke('openFullScreenIntentSettings', false);

  Future<bool> canScheduleExactAlarms() =>
      _invoke('canScheduleExactAlarms', false);

  /// Opens Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM. Returns whether
  /// the settings screen was actually launched.
  Future<bool> openExactAlarmSettings() =>
      _invoke('openExactAlarmSettings', false);

  Future<String> getManufacturer() => _invoke('getManufacturer', 'unknown');

  /// Best-effort deep link into a known aggressive-OEM autostart screen.
  /// Returns whether one was found and launched — callers should fall back
  /// to the universal ignore-battery-optimizations request regardless.
  Future<bool> openOemAutostartSettings() =>
      _invoke('openOemAutostartSettings', false);

  /// Screen pinning (`Activity.startLockTask()`) — see the native
  /// implementation's doc comment for exactly what this does and doesn't
  /// restrict. Best-effort: returns whether pinning actually engaged: a
  /// duplicate call or a not-yet-resumed Activity returns false rather
  /// than throwing, since this must never be allowed to block the ring
  /// flow itself.
  Future<bool> startAlarmLockdown() => _invoke('startAlarmLockdown', false);

  Future<bool> stopAlarmLockdown() => _invoke('stopAlarmLockdown', false);
}
