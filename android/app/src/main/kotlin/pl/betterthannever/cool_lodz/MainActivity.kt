package pl.betterthannever.cool_lodz

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import pl.betterthannever.cool_lodz.heat.HeatGuardConfig
import pl.betterthannever.cool_lodz.heat.HeatGuardService
import pl.betterthannever.cool_lodz.heat.SmsSender

/** Hosts Flutter and the `cool_lodz/heat_guard` channel («Alarm upałowy»). */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingCheck = false
    private var permissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_HEAT_CHECK, false) != true) return
        intent.removeExtra(EXTRA_HEAT_CHECK)
        showOverLockScreen(true)
        pendingCheck = true
        channel?.invokeMethod("check", null)
    }

    /** The check screen shows over the lock screen and wakes the display. */
    private fun showOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    HeatGuardConfig.save(this, call.arguments as String)
                    if (HeatGuardService.running) HeatGuardService.start(this)
                    result.success(null)
                }
                "start" -> {
                    HeatGuardService.start(this)
                    result.success(null)
                }
                "stop" -> {
                    HeatGuardService.stop(this)
                    result.success(null)
                }
                "test" -> {
                    HeatGuardService.start(this, HeatGuardService.ACTION_TEST)
                    result.success(null)
                }
                "answer" -> {
                    val action = if (call.arguments == "help") {
                        HeatGuardService.ACTION_HELP
                    } else {
                        HeatGuardService.ACTION_OK
                    }
                    if (action == HeatGuardService.ACTION_OK) showOverLockScreen(false)
                    HeatGuardService.start(this, action)
                    result.success(null)
                }
                "status" -> result.success(
                    mapOf(
                        "running" to HeatGuardService.running,
                        "hot" to HeatGuardService.hot,
                        "temperature" to HeatGuardService.temperature,
                        "phase" to HeatGuardService.phase.name.lowercase(),
                        "smsSentTo" to HeatGuardService.smsSentTo,
                    ),
                )
                "pendingCheck" -> {
                    result.success(pendingCheck || HeatGuardService.phase != HeatGuardService.Phase.IDLE)
                    pendingCheck = false
                }
                "checkClosed" -> {
                    showOverLockScreen(false)
                    result.success(null)
                }
                "permissions" -> result.success(permissions())
                "request" -> request(call.arguments as String, result)
                "openSettings" -> {
                    openSettings(call.arguments as String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        if (pendingCheck) ch.invokeMethod("check", null)
    }

    private fun granted(permission: String) =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun permissions(): Map<String, Boolean> {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return mapOf(
            "location" to granted(Manifest.permission.ACCESS_FINE_LOCATION),
            "backgroundLocation" to (Build.VERSION.SDK_INT < 29 ||
                granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
            "notifications" to nm.areNotificationsEnabled(),
            "sms" to granted(Manifest.permission.SEND_SMS),
            "telephony" to packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING),
            "smsReady" to SmsSender.canSend(this),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "battery" to pm.isIgnoringBatteryOptimizations(packageName),
        )
    }

    private fun request(kind: String, result: MethodChannel.Result) {
        val permission = when (kind) {
            "location" -> Manifest.permission.ACCESS_FINE_LOCATION
            "backgroundLocation" ->
                if (Build.VERSION.SDK_INT >= 29) Manifest.permission.ACCESS_BACKGROUND_LOCATION else null
            "notifications" ->
                if (Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null
            "sms" -> Manifest.permission.SEND_SMS
            else -> null
        }
        if (permission == null || granted(permission)) {
            result.success(true)
            return
        }
        permissionResult?.success(false)
        permissionResult = result
        val list = if (permission == Manifest.permission.ACCESS_FINE_LOCATION) {
            arrayOf(permission, Manifest.permission.ACCESS_COARSE_LOCATION)
        } else {
            arrayOf(permission)
        }
        requestPermissions(list, PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
    }

    private fun openSettings(kind: String) {
        val app = Uri.parse("package:$packageName")
        val intent = when (kind) {
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) {
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, app)
            } else {
                null
            }
            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, app)
            else -> null
        } ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app)
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, app))
        }
    }

    companion object {
        const val CHANNEL = "cool_lodz/heat_guard"
        const val EXTRA_HEAT_CHECK = "heat_check"
        private const val PERMISSION_REQUEST = 4100
    }
}
