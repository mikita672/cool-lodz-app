package pl.betterthannever.cool_lodz.heat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StillnessDetectorTest {
    private val min = 60_000L

    // ~1.1 m per 0.00001° of latitude.
    private fun fix(northM: Double, t: Long, acc: Float = 10f) =
        Fix(51.77 + northM / 111_195.0, 19.46, acc, t)

    /** Walks 300 m north in 4 minutes, then stands still. */
    private fun walkThenStop(d: StillnessDetector, stopAt: Long) {
        for (i in 0..12) d.add(fix(i * 25.0, stopAt - 4 * min + i * 20_000L))
        d.add(fix(300.0, stopAt))
    }

    @Test
    fun asksAfterWalkingAndStandingStillForTheWait() {
        val d = StillnessDetector(waitMs = 7 * min)
        walkThenStop(d, 0)
        for (t in 1..10) d.add(fix(300.0 + (t % 3) * 5, t * min)) // GPS jitter
        assertFalse(d.shouldCheck(6 * min))
        assertTrue(d.shouldCheck(7 * min + 1))
    }

    @Test
    fun noCheckWhenStillSinceMonitoringBegan() {
        val d = StillnessDetector(waitMs = 7 * min)
        for (t in 0..20) d.add(fix(0.0, t * min))
        assertNull(d.stopStart())
        assertFalse(d.shouldCheck(20 * min))
    }

    @Test
    fun aLongStopIsRememberedAfterTheWalkLeavesTheHistory() {
        val d = StillnessDetector(waitMs = 7 * min)
        walkThenStop(d, 0)
        val start = d.stopStart()
        for (t in 1..60) d.add(fix(300.0, t * min))
        assertEquals(start, d.stopStart())
        assertTrue(d.shouldCheck(60 * min))
    }

    @Test
    fun noCheckWhileWalking() {
        val d = StillnessDetector(waitMs = 7 * min)
        for (i in 0..60) d.add(fix(i * 25.0, i * 20_000L))
        assertFalse(d.shouldCheck(20 * min))
    }

    @Test
    fun inaccurateFixesAreIgnored() {
        val d = StillnessDetector(waitMs = 7 * min)
        walkThenStop(d, 0)
        // A wild indoor fix 200 m away would restart the stop.
        d.add(fix(500.0, 3 * min, acc = 120f))
        assertTrue(d.shouldCheck(7 * min + 1))
    }

    @Test
    fun okSilencesTheStopForHalfAnHour() {
        val d = StillnessDetector(waitMs = 7 * min)
        walkThenStop(d, 0)
        assertTrue(d.shouldCheck(8 * min))
        d.markChecked(8 * min)
        d.add(fix(300.0, 20 * min))
        assertFalse(d.shouldCheck(20 * min))
        d.add(fix(300.0, 38 * min + 1))
        assertTrue(d.shouldCheck(38 * min + 1))
    }

    @Test
    fun aNewStopIsCheckedAgain() {
        val d = StillnessDetector(waitMs = 5 * min)
        walkThenStop(d, 0)
        d.markChecked(6 * min)
        // Walk on 200 m and stop again.
        for (i in 1..8) d.add(fix(300.0 + i * 25, 6 * min + i * 20_000L))
        // Steps of 25 m are inside the 40 m stop radius: the stop may be
        // dated up to two fixes early.
        val stop = 6 * min + 8 * 20_000L
        val start = d.stopStart()!!
        assertTrue(start in stop - 40_000L..stop)
        assertTrue(d.shouldCheck(stop + 5 * min))
    }
}
