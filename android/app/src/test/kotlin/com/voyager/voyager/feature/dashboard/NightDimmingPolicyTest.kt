package com.voyager.voyager.feature.dashboard

import app.roadstr.core.time.SolarTimes
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NightDimmingPolicyTest {
    @Test
    fun beforeSunriseAndAfterSunsetAreNight() {
        val times = SolarTimes(rise = instant("2026-10-28T05:00:00Z"), set = instant("2026-10-28T17:00:00Z"))
        assertTrue(NightDimmingPolicy.isAfterDark(instant("2026-10-28T04:59:00Z"), times, 41.9))
        assertTrue(NightDimmingPolicy.isAfterDark(instant("2026-10-28T17:01:00Z"), times, 41.9))
    }

    @Test
    fun betweenSunriseAndSunsetIsDay() {
        val times = SolarTimes(rise = instant("2026-10-28T05:00:00Z"), set = instant("2026-10-28T17:00:00Z"))
        assertFalse(NightDimmingPolicy.isAfterDark(instant("2026-10-28T12:00:00Z"), times, 41.9))
    }

    @Test
    fun individualMissingSolarEventsUseConservativeFallbacks() {
        assertFalse(
            NightDimmingPolicy.isAfterDark(
                instant("2026-10-28T12:00:00Z"),
                SolarTimes(rise = instant("2026-10-28T05:00:00Z"), set = null),
                41.9,
            ),
        )
        assertTrue(
            NightDimmingPolicy.isAfterDark(
                instant("2026-10-28T12:00:00Z"),
                SolarTimes(rise = null, set = instant("2026-10-28T17:00:00Z")),
                41.9,
            ),
        )
    }

    @Test
    fun polarDayAndNightAreDistinguishedAtBothSolstices() {
        val noSolarEvents = SolarTimes(rise = null, set = null)
        assertFalse(NightDimmingPolicy.isAfterDark(instant("2026-06-21T12:00:00Z"), noSolarEvents, 78.0))
        assertTrue(NightDimmingPolicy.isAfterDark(instant("2026-12-21T12:00:00Z"), noSolarEvents, 78.0))
        assertTrue(NightDimmingPolicy.isAfterDark(instant("2026-06-21T12:00:00Z"), noSolarEvents, -78.0))
        assertFalse(NightDimmingPolicy.isAfterDark(instant("2026-12-21T12:00:00Z"), noSolarEvents, -78.0))
    }

    @Test
    fun scrimOnlyAppearsWhenEnabledAndDark() {
        assertEquals(0f, NightDimmingPolicy.dimOpacity(enabled = false, isNight = true), 0f)
        assertEquals(0f, NightDimmingPolicy.dimOpacity(enabled = true, isNight = false), 0f)
        assertEquals(0.65f, NightDimmingPolicy.dimOpacity(enabled = true, isNight = true), 0f)
    }

    private fun instant(value: String): Instant = Instant.parse(value)
}
