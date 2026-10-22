package pl.betterthannever.cool_lodz.heat

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import pl.betterthannever.cool_lodz.MainActivity
import pl.betterthannever.cool_lodz.R
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread
import kotlin.math.roundToInt

/**
 * Settings of the daily heat jobs (JSON from Flutter, prefs `heat_daily`):
 * `{"imgw": true, "morning": true, "checkin": false, "checkinHour": 9,
 *   "deadlineHour": 11, "morningCelsius": 26, "checkinCelsius": 30,
 *   "name": "Ania", "coolPlace": "Biblioteka…", "contacts": [{"name", "phone"}],
 *   "texts": {key: text}}`.
 */
class HeatDailyConfig(json: JSONObject) {
    val imgw = json.optBoolean("imgw", true)
    val morning = json.optBoolean("morning", true)
    val checkin = json.optBoolean("checkin", false)
    val checkinHour = json.optInt("checkinHour", 9).coerceIn(5, 20)
    val deadlineHour = json.optInt("deadlineHour", 11).coerceIn(checkinHour + 1, 22)
    val morningCelsius = json.optDouble("morningCelsius", 26.0)
    val checkinCelsius = json.optDouble("checkinCelsius", 30.0)
    val name = json.optString("name", "")
    val coolPlace = json.optString("coolPlace", "")
    val contacts: List<Pair<String, String>> = json.optJSONArray("contacts")?.let { a ->
        (0 until a.length()).mapNotNull { i ->
            a.optJSONObject(i)?.let { it.optString("name") to it.optString("phone") }
        }.filter { it.second.isNotBlank() }
    } ?: emptyList()
    private val texts = json.optJSONObject("texts") ?: JSONObject()

    fun text(key: String, vararg args: Pair<String, String>): String {
        var s = texts.optString(key, key)
        for ((k, v) in args) s = s.replace("{$k}", v)
        return s
    }

    companion object {
        private const val KEY = "config"

        fun save(context: Context, json: String) =
            HeatDaily.prefs(context).edit().putString(KEY, json).apply()

        fun load(context: Context): HeatDailyConfig? =
            HeatDaily.prefs(context).getString(KEY, null)?.let {
                try {
                    HeatDailyConfig(JSONObject(it))
                } catch (_: Exception) {
                    null
                }
            }
    }
}

/**
 * Heat jobs without a server, on AlarmManager: IMGW heat warnings for Łódź
 * every 3 hours, «dziś upał» at 7:00 and the daily «Czuję się dobrze»
 * check-in (SMS to the trusted contacts when there is no tap by the
 * deadline). Inexact alarms: no exact-alarm permission needed.
 */
object HeatDaily {
    private const val TAG = "HeatDaily"
    const val ACTION_IMGW = "pl.betterthannever.cool_lodz.heat.IMGW"
    const val ACTION_MORNING = "pl.betterthannever.cool_lodz.heat.MORNING"
    const val ACTION_CHECKIN = "pl.betterthannever.cool_lodz.heat.CHECKIN"
    const val ACTION_CHECKIN_OK = "pl.betterthannever.cool_lodz.heat.CHECKIN_OK"
    const val ACTION_DEADLINE = "pl.betterthannever.cool_lodz.heat.DEADLINE"
    private const val CHANNEL = "heat_daily"
    private const val IMGW_ID = 4201
    private const val MORNING_ID = 4202
    private const val CHECKIN_ID = 4203
    private const val IMGW_EVERY_MS = 3 * 60 * 60_000L
    private const val MORNING_HOUR = 7

    fun prefs(context: Context) = context.getSharedPreferences("heat_daily", Context.MODE_PRIVATE)

    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun pending(context: Context, action: String, code: Int) = PendingIntent.getBroadcast(
        context,
        code,
        Intent(context, HeatAlarmsReceiver::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** The next [hour]:00 (local), today if still ahead. */
    private fun nextAt(hour: Int): Long {
        val c = Calendar.getInstance()
        val now = c.timeInMillis
        c.set(Calendar.HOUR_OF_DAY, hour)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        if (c.timeInMillis <= now + 30_000) c.add(Calendar.DAY_OF_YEAR, 1)
        return c.timeInMillis
    }

    private fun at(context: Context, action: String, code: Int, time: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(context, action, code)
        if (Build.VERSION.SDK_INT >= 23) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
        } else {
            am.set(AlarmManager.RTC_WAKEUP, time, pi)
        }
    }

    private fun cancel(context: Context, action: String, code: Int) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .cancel(pending(context, action, code))
    }

    /** Sets (or clears) every alarm for the saved settings. */
    fun schedule(context: Context) {
        val cfg = HeatDailyConfig.load(context)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (cfg?.imgw == true) {
            am.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + 60_000L,
                IMGW_EVERY_MS,
                pending(context, ACTION_IMGW, 1),
            )
        } else {
            cancel(context, ACTION_IMGW, 1)
        }
        if (cfg?.morning == true || cfg?.checkin == true) {
            at(context, ACTION_MORNING, 2, nextAt(MORNING_HOUR))
        } else {
            cancel(context, ACTION_MORNING, 2)
        }
        if (cfg?.checkin == true) {
            at(context, ACTION_CHECKIN, 3, nextAt(cfg.checkinHour))
            at(context, ACTION_DEADLINE, 4, nextAt(cfg.deadlineHour))
        } else {
            cancel(context, ACTION_CHECKIN, 3)
            cancel(context, ACTION_DEADLINE, 4)
        }
    }

    fun handle(context: Context, action: String?) {
        val cfg = HeatDailyConfig.load(context) ?: return
        createChannel(context)
        when (action) {
            ACTION_IMGW -> if (cfg.imgw) checkImgw(context, cfg)
            ACTION_MORNING -> {
                morning(context, cfg)
                at(context, ACTION_MORNING, 2, nextAt(MORNING_HOUR))
            }
            ACTION_CHECKIN -> {
                if (cfg.checkin) askCheckin(context, cfg)
                at(context, ACTION_CHECKIN, 3, nextAt(cfg.checkinHour))
            }
            ACTION_CHECKIN_OK -> checkinOk(context, cfg)
            ACTION_DEADLINE -> {
                if (cfg.checkin) deadline(context, cfg)
                at(context, ACTION_DEADLINE, 4, nextAt(cfg.deadlineHour))
            }
        }
    }

    // --- IMGW -----------------------------------------------------------------

    private fun get(url: String): String? = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 15_000
        c.readTimeout = 15_000
        try {
            c.inputStream.bufferedReader().readText()
        } finally {
            c.disconnect()
        }
    } catch (e: Exception) {
        Log.w(TAG, "get $url", e)
        null
    }

    private fun checkImgw(context: Context, cfg: HeatDailyConfig) {
        val body = get("https://danepubliczne.imgw.pl/api/data/warningsmeteo") ?: return
        val items = try {
            if (body.trimStart().startsWith("[")) JSONArray(body) else JSONArray()
        } catch (_: Exception) {
            return
        }
        val prefs = prefs(context)
        val seen = prefs.getStringSet("seenImgw", emptySet())!!.toMutableSet()
        val now = System.currentTimeMillis()
        var heatUntil = 0L
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            if (!HeatDailyLogic.isHeat(item.optString("nazwa_zdarzenia"))) continue
            val teryt = item.opt("teryt")
            val codes = when (teryt) {
                is JSONArray -> (0 until teryt.length()).map { teryt.optString(it) }
                is String -> teryt.split(Regex("[,;\\s]+"))
                else -> emptyList()
            }
            if (!HeatDailyLogic.coversLodz(codes)) continue
            val to = HeatDailyLogic.parseWarsaw(item.optString("obowiazuje_do")) ?: continue
            if (to <= now) continue
            heatUntil = maxOf(heatUntil, to)
            val id = item.optString("id").ifBlank { item.optString("obowiazuje_od") }
            if (!seen.add(id)) continue
            val from = HeatDailyLogic.parseWarsaw(item.optString("obowiazuje_od")) ?: now
            val f = SimpleDateFormat("d.MM HH:mm", Locale("pl"))
            val level = item.optString("stopien", "1")
            notify(
                context,
                IMGW_ID + (id.hashCode() and 0xff),
                cfg.text("imgwTitle", "level" to level),
                cfg.text("imgwBody", "from" to f.format(Date(from)), "to" to f.format(Date(to))),
                alert = true,
            )
        }
        prefs.edit()
            .putStringSet("seenImgw", seen.toList().takeLast(50).toSet())
            .putLong("heatUntil", heatUntil)
            .apply()
    }

    // --- 7:00 -----------------------------------------------------------------

    /** Today's 24 hourly feels-like temperatures in Łódź, or null offline. */
    private fun todayFeels(): List<Double?>? {
        val body = get(
            "https://api.open-meteo.com/v1/forecast?latitude=51.77&longitude=19.46" +
                "&hourly=apparent_temperature&forecast_days=1&timezone=Europe%2FWarsaw",
        ) ?: return null
        return try {
            val a = JSONObject(body).getJSONObject("hourly").getJSONArray("apparent_temperature")
            (0 until a.length()).map { if (a.isNull(it)) null else a.getDouble(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun morning(context: Context, cfg: HeatDailyConfig) {
        val feels = todayFeels() ?: return
        val max = feels.filterNotNull().maxOrNull() ?: return
        val hot = max >= cfg.checkinCelsius ||
            prefs(context).getLong("heatUntil", 0) > System.currentTimeMillis()
        prefs(context).edit().putString("hotDay", if (hot) today() else "").apply()
        val hours = HeatDailyLogic.hotHours(feels, cfg.morningCelsius) ?: return
        val (before, after) = hours
        val maxText = max.roundToInt().toString()
        val body = if (before <= MORNING_HOUR + 1 && after >= 21) {
            cfg.text("morningAllDay")
        } else {
            cfg.text("morningBody", "before" to "$before:00", "after" to "$after:00")
        }
        val place = if (cfg.coolPlace.isNotBlank()) " " + cfg.text("morningPlace", "place" to cfg.coolPlace) else ""
        HeatWidget.save(
            context,
            level = when {
                max >= 38 -> 3
                max >= 32 -> 2
                else -> 1
            },
            title = cfg.text("widgetTitle", "max" to maxText),
            line = cfg.text("widgetHours", "before" to "$before:00", "after" to "$after:00"),
        )
        if (cfg.morning) {
            notify(context, MORNING_ID, cfg.text("morningTitle", "max" to maxText), body + place)
        }
    }

    // --- Check-in -------------------------------------------------------------

    /** Hot today: from the 7:00 forecast or an IMGW warning. */
    private fun hotToday(context: Context): Boolean {
        val p = prefs(context)
        if (p.getLong("heatUntil", 0) > System.currentTimeMillis()) return true
        if (p.getString("hotDay", "") == today()) return true
        val max = todayFeels()?.filterNotNull()?.maxOrNull() ?: return false
        return max >= (HeatDailyConfig.load(context)?.checkinCelsius ?: 30.0)
    }

    private fun askCheckin(context: Context, cfg: HeatDailyConfig) {
        if (!hotToday(context)) return
        prefs(context).edit().putString("askedDay", today()).apply()
        val ok = PendingIntent.getBroadcast(
            context,
            5,
            Intent(context, HeatAlarmsReceiver::class.java).setAction(ACTION_CHECKIN_OK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = builder(context)
            .setContentTitle(cfg.text("checkinTitle"))
            .setContentText(cfg.text("checkinBody", "deadline" to "${cfg.deadlineHour}:00"))
            .setStyle(
                Notification.BigTextStyle().bigText(cfg.text("checkinBody", "deadline" to "${cfg.deadlineHour}:00")),
            )
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, cfg.text("checkinAction"), ok).build())
            .build()
        nm(context).notify(CHECKIN_ID, n)
    }

    /** Also called from the app («Czuję się dobrze» on the home screen). */
    fun checkinOk(context: Context, cfg: HeatDailyConfig?) {
        prefs(context).edit().putString("okDay", today()).apply()
        nm(context).cancel(CHECKIN_ID)
        if (cfg != null) notify(context, CHECKIN_ID, cfg.text("checkinThanks"), "")
    }

    /** Asked today and no answer yet. */
    fun checkinPending(context: Context): Boolean {
        val p = prefs(context)
        return p.getString("askedDay", "") == today() && p.getString("okDay", "") != today()
    }

    private fun deadline(context: Context, cfg: HeatDailyConfig) {
        if (!checkinPending(context)) return
        val text = cfg.text("checkinSms", "name" to cfg.name, "deadline" to "${cfg.deadlineHour}:00")
        val sent = SmsSender.send(context, cfg.contacts.map { it.second }, text)
        val names = cfg.contacts.filter { it.second in sent }.map { it.first.ifBlank { it.second } }
        prefs(context).edit().putString("okDay", today()).apply() // once a day
        nm(context).cancel(CHECKIN_ID)
        notify(
            context,
            CHECKIN_ID,
            cfg.text("checkinMissedTitle"),
            if (names.isEmpty()) cfg.text("checkinNoSms") else cfg.text("checkinSmsSent", "names" to names.joinToString(", ")),
            alert = true,
        )
    }

    // --- Notifications --------------------------------------------------------

    private fun nm(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        nm(context).createNotificationChannel(
            NotificationChannel(CHANNEL, "Upał: ostrzeżenia i codzienne pytanie", NotificationManager.IMPORTANCE_HIGH),
        )
    }

    private fun builder(context: Context): Notification.Builder {
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val open = PendingIntent.getActivity(
            context,
            6,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(MainActivity.EXTRA_OPEN_ALERT, true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return b.setSmallIcon(R.drawable.ic_heat_guard).setContentIntent(open).setAutoCancel(true)
    }

    private fun notify(context: Context, id: Int, title: String, body: String, alert: Boolean = false) {
        val b = builder(context).setContentTitle(title)
        if (body.isNotBlank()) b.setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
        if (alert) b.setCategory(Notification.CATEGORY_ALARM)
        try {
            nm(context).notify(id, b.build())
        } catch (e: SecurityException) {
            Log.w(TAG, "notify", e) // notifications not allowed
        }
    }
}

/** Runs the [HeatDaily] jobs and sets them again after a reboot or update. */
class HeatAlarmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            HeatDaily.schedule(context)
            if (HeatGuardService.wanted(context)) {
                try {
                    HeatGuardService.start(context)
                } catch (e: Exception) {
                    Log.w("HeatDaily", "restart guard", e)
                }
            }
            return
        }
        val done = goAsync()
        val app = context.applicationContext
        thread(name = "heat-daily") {
            try {
                HeatDaily.handle(app, action)
            } catch (e: Exception) {
                Log.w("HeatDaily", "handle $action", e)
            } finally {
                done.finish()
            }
        }
    }
}
