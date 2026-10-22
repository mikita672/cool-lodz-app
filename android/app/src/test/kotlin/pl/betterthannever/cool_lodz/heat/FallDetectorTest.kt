package pl.betterthannever.cool_lodz.heat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class FallDetectorTest {
    /** Feeds [ms] of samples at 50 Hz with magnitude [a]; counts falls. */
    private fun FallDetector.feed(a: Double, ms: Long, start: Long): Pair<Int, Long> {
        var t = start
        var falls = 0
        while (t < start + ms) {
            if (addMagnitude(a, t)) falls++
            t += 20
        }
        return falls to t
    }

    @Test
    fun fallThenLyingStillIsDetected() {
        val d = FallDetector()
        var t = 0L
        var falls = 0
        for ((a, ms) in listOf(9.8 to 1000L, 1.0 to 200L, 30.0 to 40L, 9.8 to 11_000L)) {
            val (f, next) = d.feed(a, ms, t)
            falls += f
            t = next
        }
        assertEquals(1, falls)
    }

    @Test
    fun walkingAfterTheImpactIsNotAFall() {
        val d = FallDetector()
        var t = 0L
        var falls = 0
        for ((a, ms) in listOf(1.0 to 200L, 30.0 to 40L, 14.0 to 3000L, 9.8 to 11_000L)) {
            val (f, next) = d.feed(a, ms, t)
            falls += f
            t = next
        }
        assertEquals(0, falls)
    }

    @Test
    fun aJoltWithoutFreeFallIsNothing() {
        val d = FallDetector()
        val (f1, t) = d.feed(30.0, 100, 0)
        val (f2, _) = d.feed(9.8, 12_000, t)
        assertEquals(0, f1 + f2)
    }

    @Test
    fun freeFallWithoutImpactResets() {
        val d = FallDetector()
        val (f1, t) = d.feed(1.0, 200, 0)
        val (f2, _) = d.feed(9.8, 12_000, t)
        assertFalse(f1 + f2 > 0)
    }
}
