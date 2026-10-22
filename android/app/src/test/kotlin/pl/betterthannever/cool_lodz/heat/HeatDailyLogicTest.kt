package pl.betterthannever.cool_lodz.heat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HeatDailyLogicTest {
    @Test
    fun hotHoursAreTheFirstAndLastHourAboveTheThreshold() {
        val feels = (0 until 24).map { h -> if (h in 11..17) 31.0 else 22.0 }
        assertEquals(11 to 18, HeatDailyLogic.hotHours(feels, 26.0))
    }

    @Test
    fun noHotHourMeansNull() {
        assertNull(HeatDailyLogic.hotHours(List(24) { 20.0 }, 26.0))
        assertNull(HeatDailyLogic.hotHours(List(24) { null }, 26.0))
    }

    @Test
    fun heatWarningMatchesWithAndWithoutPolishLetters() {
        assertTrue(HeatDailyLogic.isHeat("Upał"))
        assertTrue(HeatDailyLogic.isHeat("UPAL"))
        assertFalse(HeatDailyLogic.isHeat("Burze z gradem"))
        assertFalse(HeatDailyLogic.isHeat(null))
    }

    @Test
    fun lodzCountyAndItsCommunes() {
        assertTrue(HeatDailyLogic.coversLodz(listOf("1001", "1061")))
        assertTrue(HeatDailyLogic.coversLodz(listOf(" 106101")))
        assertFalse(HeatDailyLogic.coversLodz(listOf("1062")))
    }

    @Test
    fun warsawTimeIsParsed() {
        // 12:00 in Warsaw summer time is 10:00 UTC.
        assertEquals(1782900000000L, HeatDailyLogic.parseWarsaw("2026-07-01 12:00:00"))
        assertNull(HeatDailyLogic.parseWarsaw("jutro"))
    }
}
