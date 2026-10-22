package pl.betterthannever.cool_lodz.heat

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import org.json.JSONObject
import pl.betterthannever.cool_lodz.MainActivity
import pl.betterthannever.cool_lodz.R
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/**
 * «Alarm upałowy»: a foreground service that, while it is hot, watches
 * where the user is. After walking somewhere and staying still for the set
 * time it asks «Wszystko w porządku?» (full-screen notification); with no
 * answer the siren plays at half volume for 30 s, then at full volume with
 * the flashlight, and the trusted contacts get an SMS with the location.
 */
class HeatGuardService : Service(), LocationListener, SensorEventListener {

    enum class Phase { IDLE, ASK, HALF, FULL }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var alarm: AlarmPlayer
    private var config: HeatGuardConfig? = null
    private val detector = StillnessDetector(waitMs = 7 * 60_000L)
    private var tracking = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var test = false

    /** Started by the switch (not only for a test). */
    private var monitoring = false
    private var alarmLock: PowerManager.WakeLock? = null
    private val fall = FallDetector()
    private var sensing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        alarm = AlarmPlayer(this)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        config = HeatGuardConfig.load(this)
        val cfg = config
        if (cfg == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        detector.waitMs = cfg.waitMinutes * 60_000L
        if (tracking) {
            if (cfg.fallDetection) startFallSensor() else stopFallSensor()
        }
        if (!startInForeground()) {
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        when (intent?.action) {
            ACTION_OK -> answerOk()
            ACTION_HELP -> escalate(Phase.FULL)
            ACTION_TEST -> {
                if (phase == Phase.IDLE) {
                    test = true
                    ask()
                }
            }
            else -> {
                monitoring = true
                handler.removeCallbacks(heatCheck)
                handler.post(heatCheck)
                handler.removeCallbacks(tick)
                handler.postDelayed(tick, TICK_MS)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        hot = false
        stopTracking()
        alarm.stop()
        phase = Phase.IDLE
        handler.removeCallbacksAndMessages(null)
        releaseWakeLock()
        alarmLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    // --- Heat ---------------------------------------------------------------

    private val heatCheck = object : Runnable {
        override fun run() {
            val cfg = config ?: return
            thread(name = "heat-check") {
                val t = fetchTemperature()
                handler.post {
                    temperature = t?.first
                    val apparent = t?.second
                    hot = !cfg.heatOnly ||
                        System.currentTimeMillis() < cfg.heatUntil ||
                        (temperature ?: -99.0) >= cfg.hotCelsius ||
                        (apparent ?: -99.0) >= cfg.hotCelsius + 2
                    if (hot) startTracking() else stopTracking()
                    updateNotification()
                }
            }
            handler.postDelayed(this, HEAT_CHECK_MS)
        }
    }

    /** (temperature, apparent temperature) now in Łódź, or null offline. */
    private fun fetchTemperature(): Pair<Double, Double?>? = try {
        val url = URL(
            "https://api.open-meteo.com/v1/forecast?latitude=51.77&longitude=19.46" +
                "&current=temperature_2m,apparent_temperature",
        )
        val c = url.openConnection() as HttpURLConnection
        c.connectTimeout = 10_000
        c.readTimeout = 10_000
        try {
            val body = c.inputStream.bufferedReader().readText()
            val current = JSONObject(body).getJSONObject("current")
            current.getDouble("temperature_2m") to
                current.optDouble("apparent_temperature").takeIf { !it.isNaN() }
        } finally {
            c.disconnect()
        }
    } catch (e: Exception) {
        Log.w(TAG, "temperature", e)
        null
    }

    // --- Location -----------------------------------------------------------

    @SuppressLint("MissingPermission")
    private fun startTracking() {
        if (tracking || !hasLocation()) return
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            if (lm.allProviders.contains(provider)) {
                try {
                    lm.requestLocationUpdates(provider, FIX_MS, 0f, this, Looper.getMainLooper())
                } catch (e: Exception) {
                    Log.w(TAG, "updates $provider", e)
                }
            }
        }
        tracking = true
        startFallSensor()
        // Timers must run with the screen off while it is hot.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "coollodz:heatguard").apply {
            setReferenceCounted(false)
            acquire(HEAT_CHECK_MS + 60_000L)
        }
    }

    private fun stopTracking() {
        if (!tracking) return
        (getSystemService(Context.LOCATION_SERVICE) as LocationManager).removeUpdates(this)
        stopFallSensor()
        tracking = false
        releaseWakeLock()
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun hasLocation() =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun onLocationChanged(location: Location) {
        detector.add(
            Fix(location.latitude, location.longitude, location.accuracy, System.currentTimeMillis()),
        )
        lastLat = location.latitude
        lastLon = location.longitude
        lastAccuracy = location.accuracy
        evaluate()
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {
    }

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    private val tick = object : Runnable {
        override fun run() {
            evaluate()
            handler.postDelayed(this, TICK_MS)
        }
    }

    private fun evaluate() {
        if (!hot || phase != Phase.IDLE) return
        val now = System.currentTimeMillis()
        if (!detector.shouldCheck(now)) return
        detector.markChecked(now)
        if (nearSafePlace()) return
        test = false
        ask()
    }

    private fun nearSafePlace(): Boolean {
        val cfg = config ?: return false
        val fix = detector.latest ?: return false
        val places = listOfNotNull(cfg.home) + cfg.safePlaces
        return places.any { (lat, lon) ->
            StillnessDetector.distanceM(fix.lat, fix.lon, lat, lon) <= SAFE_RADIUS_M
        }
    }

    // --- Fall detection ------------------------------------------------------

    private fun startFallSensor() {
        if (sensing || config?.fallDetection != true) return
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val acc = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        sensing = sm.registerListener(this, acc, SensorManager.SENSOR_DELAY_GAME, handler)
    }

    private fun stopFallSensor() {
        if (!sensing) return
        (getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(this)
        sensing = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        val v = event.values
        if (!fall.add(v[0], v[1], v[2], event.timestamp / 1_000_000L)) return
        if (phase != Phase.IDLE) return
        Log.i(TAG, "fall detected")
        fellAt = System.currentTimeMillis()
        test = false
        ask()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // --- The check and the alarm -------------------------------------------

    private fun ask() {
        phase = Phase.ASK
        // The steps must run with the screen off.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        alarmLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "coollodz:heatalarm").apply {
            setReferenceCounted(false)
            acquire(FULL_MAX_MS + 2 * 60_000L)
        }
        smsSentTo = emptyList()
        alarm.vibrate()
        showCheckNotification()
        handler.postDelayed(toHalf, if (test) TEST_STEP_MS else STEP_MS)
    }

    private val toHalf = Runnable { escalate(Phase.HALF) }
    private val toFull = Runnable { escalate(Phase.FULL) }
    private val autoStop = Runnable { answerOk() }

    private fun escalate(to: Phase) {
        if (to.ordinal <= phase.ordinal && phase != Phase.IDLE) return
        handler.removeCallbacks(toHalf)
        handler.removeCallbacks(toFull)
        phase = to
        when (to) {
            Phase.HALF -> {
                alarm.play(0.5f)
                handler.postDelayed(toFull, if (test) TEST_STEP_MS else STEP_MS)
            }
            Phase.FULL -> {
                alarm.vibrate()
                alarm.play(1f)
                alarm.blinkTorch()
                if (!test) sendSms()
                handler.removeCallbacks(autoStop)
                handler.postDelayed(autoStop, if (test) TEST_STEP_MS * 2 else FULL_MAX_MS)
            }
            else -> {}
        }
        showCheckNotification()
    }

    private fun answerOk() {
        handler.removeCallbacks(toHalf)
        handler.removeCallbacks(toFull)
        handler.removeCallbacks(autoStop)
        alarm.stop()
        phase = Phase.IDLE
        test = false
        fellAt = 0L
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(CHECK_ID)
        updateNotification()
        alarmLock?.let { if (it.isHeld) it.release() }
        alarmLock = null
        // Started only for a test: nothing to watch.
        if (!monitoring) stopSelf()
    }

    private fun sendSms() {
        val cfg = config ?: return
        val lat = lastLat
        val lon = lastLon
        val time = SimpleDateFormat("HH:mm", Locale("pl")).format(Date())
        val place = if (lat != null && lon != null) {
            cfg.text(
                "smsPlace",
                "link" to "https://maps.google.com/?q=%.6f,%.6f".format(Locale.US, lat, lon),
                "accuracy" to (lastAccuracy?.roundToInt()?.toString() ?: "?"),
            )
        } else {
            cfg.text("smsNoPlace")
        }
        val text = cfg.text("sms", "place" to place, "time" to time)
        val numbers = cfg.contacts.map { it.second }
        thread(name = "heat-sms") {
            val sent = SmsSender.send(this, numbers, text)
            handler.post {
                smsSentTo = cfg.contacts.filter { it.second in sent }.map { it.first.ifBlank { it.second } }
                showCheckNotification()
            }
        }
    }

    // --- Notifications ------------------------------------------------------

    private fun createChannels() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_MONITOR, "Alarm upałowy", NotificationManager.IMPORTANCE_LOW),
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_CHECK, "Alarm upałowy: pytanie", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null) // the siren is played by AlarmPlayer
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun openAppIntent(check: Boolean): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (check) putExtra(MainActivity.EXTRA_HEAT_CHECK, true)
        }
        return PendingIntent.getActivity(
            this,
            if (check) 2 else 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun serviceIntent(action: String, code: Int) = PendingIntent.getService(
        this,
        code,
        Intent(this, HeatGuardService::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun monitorNotification(): Notification {
        val cfg = config
        val t = temperature?.roundToInt()?.toString() ?: "?"
        val text = when {
            cfg == null -> ""
            hot -> cfg.text("monitorWatching", "temp" to t)
            else -> cfg.text("monitorWaiting", "temp" to t)
        }
        return Notification.Builder(this, CHANNEL_MONITOR)
            .setSmallIcon(R.drawable.ic_heat_guard)
            .setContentTitle(cfg?.text("monitorTitle") ?: "")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(openAppIntent(false))
            .build()
    }

    private fun startInForeground(): Boolean = try {
        if (Build.VERSION.SDK_INT >= 29) {
            val type = if (hasLocation()) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            } else {
                0
            }
            startForeground(MONITOR_ID, monitorNotification(), type)
        } else {
            startForeground(MONITOR_ID, monitorNotification())
        }
        true
    } catch (e: Exception) {
        Log.w(TAG, "foreground", e)
        false
    }

    private fun updateNotification() {
        if (!running) return
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(MONITOR_ID, monitorNotification())
    }

    private fun showCheckNotification() {
        val cfg = config ?: return
        val alarmOn = phase == Phase.HALF || phase == Phase.FULL
        val body = when {
            smsSentTo.isNotEmpty() -> cfg.text("checkSmsSent", "names" to smsSentTo.joinToString(", "))
            alarmOn -> cfg.text("checkAlarmBody")
            System.currentTimeMillis() - fellAt < 5 * 60_000L -> cfg.text("checkFallBody")
            else -> cfg.text("checkBody")
        }
        val n = Notification.Builder(this, CHANNEL_CHECK)
            .setSmallIcon(R.drawable.ic_heat_guard)
            .setContentTitle(cfg.text(if (alarmOn) "checkAlarmTitle" else "checkTitle"))
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(openAppIntent(true))
            .setFullScreenIntent(openAppIntent(true), true)
            .addAction(
                Notification.Action.Builder(null, cfg.text("actionOk"), serviceIntent(ACTION_OK, 3)).build(),
            )
            .addAction(
                Notification.Action.Builder(null, cfg.text("actionHelp"), serviceIntent(ACTION_HELP, 4)).build(),
            )
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(CHECK_ID, n)
    }

    companion object {
        private const val TAG = "HeatGuard"
        const val ACTION_START = "pl.betterthannever.cool_lodz.heat.START"
        const val ACTION_OK = "pl.betterthannever.cool_lodz.heat.OK"
        const val ACTION_HELP = "pl.betterthannever.cool_lodz.heat.HELP"
        const val ACTION_TEST = "pl.betterthannever.cool_lodz.heat.TEST"
        private const val CHANNEL_MONITOR = "heat_guard"
        private const val CHANNEL_CHECK = "heat_guard_check"
        private const val MONITOR_ID = 4101
        private const val CHECK_ID = 4102
        private const val FIX_MS = 20_000L
        private const val TICK_MS = 15_000L
        private const val HEAT_CHECK_MS = 30 * 60_000L
        private const val STEP_MS = 30_000L
        private const val TEST_STEP_MS = 5_000L
        private const val FULL_MAX_MS = 15 * 60_000L
        private const val SAFE_RADIUS_M = 80.0

        // Read by MainActivity for the Flutter side.
        @Volatile var running = false
        @Volatile var hot = false
        @Volatile var temperature: Double? = null
        @Volatile var phase = Phase.IDLE
        @Volatile var smsSentTo: List<String> = emptyList()
        @Volatile var lastLat: Double? = null
        @Volatile var lastLon: Double? = null
        @Volatile var lastAccuracy: Float? = null
        @Volatile var fellAt = 0L

        /** The user turned the alarm on (restarted after a reboot). */
        fun wanted(context: Context) =
            context.getSharedPreferences("heat_guard", Context.MODE_PRIVATE).getBoolean("wanted", false)

        private fun setWanted(context: Context, on: Boolean) =
            context.getSharedPreferences("heat_guard", Context.MODE_PRIVATE).edit().putBoolean("wanted", on).apply()

        fun start(context: Context, action: String = ACTION_START) {
            if (action == ACTION_START) setWanted(context, true)
            val intent = Intent(context, HeatGuardService::class.java).setAction(action)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            setWanted(context, false)
            context.stopService(Intent(context, HeatGuardService::class.java))
        }
    }
}
