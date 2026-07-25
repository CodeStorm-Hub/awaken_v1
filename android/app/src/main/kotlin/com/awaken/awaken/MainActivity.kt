package com.awaken.awaken

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bypasses the lock screen for full-screen-intent alarms (plan
 * awaken_app_refined_plan.md C6) and exposes system-capability checks the
 * `alarm` package itself doesn't cover: FSI/exact-alarm capability probes
 * and best-effort OEM autostart/battery-exemption deep links (H4).
 */
class MainActivity : FlutterActivity() {
    private val capabilitiesChannel = "com.awaken.awaken/system_capabilities"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenFlags()
    }

    private fun applyLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Only dismisses non-secure keyguards outright; on a secure (PIN/
        // pattern/biometric) lock screen this surfaces the standard unlock
        // prompt over our activity rather than forcing it immediately.
        val keyguardManager = getSystemService(KEYGUARD_SERVICE) as? KeyguardManager
        keyguardManager?.requestDismissKeyguard(this, null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, capabilitiesChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
                    "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                    "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                    "getManufacturer" -> result.success(Build.MANUFACTURER)
                    "openOemAutostartSettings" -> result.success(openOemAutostartSettings())
                    "startAlarmLockdown" -> result.success(startAlarmLockdown())
                    "stopAlarmLockdown" -> result.success(stopAlarmLockdown())
                    else -> result.notImplemented()
                }
            }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val notificationManager = getSystemService(NotificationManager::class.java)
        return notificationManager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.fromParts("package", packageName, null)
                },
            )
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = getSystemService(AlarmManager::class.java)
        return alarmManager.canScheduleExactAlarms()
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.fromParts("package", packageName, null)
                },
            )
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * Best-effort deep link into known aggressive-OEM autostart/battery
     * settings screens (plan H4 — dontkillmyapp.com's documented set of
     * vendor components). Returns whether an intent was actually launched;
     * the Dart side falls back to the universal
     * ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS flow (via
     * permission_handler) regardless of manufacturer, since these
     * vendor-specific screens are undocumented and can disappear between
     * OS versions.
     */
    private fun openOemAutostartSettings(): Boolean {
        val components =
            listOf(
                "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
                "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
                "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            )

        for ((pkg, cls) in components) {
            try {
                startActivity(
                    Intent().apply {
                        component = android.content.ComponentName(pkg, cls)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    },
                )
                return true
            } catch (e: Exception) {
                // Not this device's manufacturer, or the screen moved — try the next.
                continue
            }
        }
        return false
    }

    /**
     * Screen pinning (`Activity.startLockTask()`) — a standard API any app
     * can call from a resumed Activity, distinct from (and far less
     * invasive than) Device Owner/kiosk mode: it disables the Home/Recents
     * buttons and shows the system's own "app is pinned" affordance, but
     * the OS *always* provides an unpin gesture (long-press Back+Overview,
     * or on gesture nav, swipe-up-and-hold) that works regardless of this
     * app's own state — so a crash or bug here can never actually strand
     * the user with no way out. Deliberately does *not* touch notification
     * shade/quick-settings access (that restriction requires Device Owner,
     * which isn't installable on an already-set-up phone via a normal app
     * flow — see the alarm-lockdown planning discussion) and never blocks
     * incoming calls, which Android's own phone UI takes over regardless
     * of pinning state.
     */
    private fun startAlarmLockdown(): Boolean {
        return try {
            startLockTask()
            true
        } catch (e: IllegalStateException) {
            // Already pinned (e.g. a duplicate call), or the activity isn't
            // in a state that allows it — not fatal, the ring screen's own
            // UI blocking (PopScope, full-screen overlay) still applies.
            false
        }
    }

    private fun stopAlarmLockdown(): Boolean {
        return try {
            stopLockTask()
            true
        } catch (e: IllegalStateException) {
            // Not currently pinned — nothing to do.
            false
        }
    }
}
