package pl.betterthannever.cool_lodz.heat

import java.text.Normalizer
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/** Pure helpers of the daily heat jobs (tested on the JVM). */
object HeatDailyLogic {
    /** TERYT code of the city county Łódź. */
    const val LODZ_TERYT = "1061"

    /**
     * The hours to stay in on a hot day from [feels] (24 hourly feels-like
     * temperatures from midnight): the first and the last hour at or above
     * [threshold]. Returns (before, after): go out before `before:00` or
     * after `after:00`; null when no hour reaches it.
     */
    fun hotHours(feels: List<Double?>, threshold: Double): Pair<Int, Int>? {
        var first = -1
        var last = -1
        for ((h, t) in feels.withIndex()) {
            if (t != null && t >= threshold) {
                if (first < 0) first = h
                last = h
            }
        }
        return if (first < 0) null else first to (last + 1).coerceAtMost(24)
    }

    /** «Upał» in any case, with or without Polish letters. */
    fun isHeat(event: String?): Boolean = event != null && plain(event).contains("upal")

    /** [teryt] is a list or a comma separated string of codes. */
    fun coversLodz(teryt: List<String>): Boolean = teryt.any { it.trim().startsWith(LODZ_TERYT) }

    /** `2026-07-01 12:00:00` (Warsaw time) → epoch ms, or null. */
    fun parseWarsaw(text: String?): Long? {
        if (text.isNullOrBlank()) return null
        for (pattern in listOf("yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss")) {
            try {
                val f = SimpleDateFormat(pattern, Locale.US)
                f.timeZone = TimeZone.getTimeZone("Europe/Warsaw")
                f.isLenient = false
                return f.parse(text.trim())?.time
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun plain(s: String) = Normalizer.normalize(s.lowercase(Locale.ROOT), Normalizer.Form.NFD)
        .replace(Regex("\\p{M}"), "")
        .replace('ł', 'l')
}
