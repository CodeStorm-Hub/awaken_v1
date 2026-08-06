import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:injectable/injectable.dart';

/// Top-level entry point required by `flutter_foreground_task` — must be a
/// free function (or static), never a closure, so the background isolate can
/// resolve it. All this task handler does is keep the while-in-use location
/// foreground service notification alive (plan H3); the actual position
/// stream is read in the main isolate via geolocator, not here — this keeps
/// the run-tracking pipeline in one isolate instead of bridging GPS fixes
/// across an isolate boundary for no benefit at v1 scale.
@pragma('vm:entry-point')
void runTrackingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_RunTrackingTaskHandler());
}

class _RunTrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Thin wrapper around `FlutterForegroundTask`'s static API (plan §6 Phase
/// 5) — a location-type foreground service + persistent notification is
/// required for Android to keep GPS alive while the app is backgrounded
/// during a run, without requesting background-location permission (H3).
///
/// Android-only: on iOS `flutter_foreground_task` is a notification-only
/// shim that grants no real background execution context, so `start()`/
/// `stop()` are no-ops there rather than calling into a plugin path that
/// wouldn't do anything useful. iOS run tracking is foreground-only until
/// its own background-location code path (via geolocator) is built — see
/// the scope note in CLAUDE.md.
@lazySingleton
class RunForegroundService {
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'awaken_run_tracking',
        channelName: 'Run tracking',
        channelDescription:
            'Keeps GPS active while a territory run is in progress.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    _ensureInitialized();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Tracking your run',
      notificationText: 'Awaken is recording your route.',
      callback: runTrackingTaskCallback,
    );
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
