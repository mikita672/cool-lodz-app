package pl.betterthannever.cool_lodz.heat

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sqrt

/** One GPS fix. */
data class Fix(val lat: Double, val lon: Double, val accuracyM: Float, val timeMs: Long)

/**
 * Decides when to ask «Wszystko w porządku?»: the person walked here (was at
 * least [arrivedFromM] away in the [arrivedWithinMs] before stopping) and has
 * stayed within [radiusM] for [waitMs]. Fixes worse than [maxAccuracyM] are
 * ignored. A stop is checked once; after «OK» it is checked again only after
 * [recheckMs].
 */
class StillnessDetector(
    var waitMs: Long,
    private val radiusM: Double = 40.0,
    private val arrivedFromM: Double = 100.0,
    private val arrivedWithinMs: Long = 10 * 60_000L,
    private val maxAccuracyM: Float = 35f,
    private val recheckMs: Long = 30 * 60_000L,
) {
    private val history = ArrayDeque<Fix>()
    private var checkedStop: Long? = null

    // The current stop, kept after the walk to it leaves the history.
    private var knownStart: Long? = null
    private var knownFix: Fix? = null
    private var okAt: Long = 0

    val latest: Fix? get() = history.lastOrNull()

    fun add(fix: Fix) {
        if (fix.accuracyM > maxAccuracyM) return
        if (history.isNotEmpty() && fix.timeMs < history.last().timeMs) return
        history.addLast(fix)
        val keep = waitMs + arrivedWithinMs + 5 * 60_000L
        while (history.isNotEmpty() && fix.timeMs - history.first().timeMs > keep) {
            history.removeFirst()
        }
        stopStart() // remembers the stop while the walk is still known
    }

    /** When the current stop began, or null when the person did not walk here. */
    fun stopStart(): Long? {
        val last = history.lastOrNull() ?: return null
        // Still at the stop we know, even after the walk here left the history.
        knownFix?.let { if (distanceM(it, last) <= radiusM) return knownStart }
        knownStart = null
        knownFix = null
        var start = last.timeMs
        var outside: Fix? = null
        for (i in history.indices.reversed()) {
            val f = history[i]
            if (distanceM(f, last) <= radiusM) start = f.timeMs else { outside = f; break }
        }
        if (outside == null) return null // still since monitoring began
        val walked = history.any {
            it.timeMs in (start - arrivedWithinMs)..start && distanceM(it, last) >= arrivedFromM
        }
        if (!walked) return null
        knownStart = start
        knownFix = last
        return start
    }

    /** True when it is time to ask (call on every fix and on a timer). */
    fun shouldCheck(nowMs: Long): Boolean {
        val start = stopStart() ?: return false
        if (nowMs - start < waitMs) return false
        if (checkedStop == start && nowMs - okAt < recheckMs) return false
        return true
    }

    /** The check for the current stop started. */
    fun markChecked(nowMs: Long) {
        checkedStop = stopStart()
        okAt = nowMs
    }

    companion object {
        fun distanceM(a: Fix, b: Fix) = distanceM(a.lat, a.lon, b.lat, b.lon)

        fun distanceM(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6_371_000.0
            val dLat = Math.toRadians(lat2 - lat1)
            val dLon = Math.toRadians(lon2 - lon1)
            val h = Math.sin(dLat / 2).let { it * it } +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2).let { it * it }
            return 2 * r * asin(sqrt(h))
        }
    }
}
