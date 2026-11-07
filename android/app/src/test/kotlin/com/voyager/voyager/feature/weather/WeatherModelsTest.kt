package com.voyager.voyager.feature.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WeatherModelsTest {
    @Test
    fun hazardsMatchDrivingSeverity() {
        assertEquals(DrivingHazard.NONE, WeatherAlerts.assess(weather(code = 0)))
        assertEquals(DrivingHazard.CAUTION, WeatherAlerts.assess(weather(code = 45)))
        assertEquals(DrivingHazard.CAUTION, WeatherAlerts.assess(weather(code = 61)))
        assertEquals(DrivingHazard.SEVERE, WeatherAlerts.assess(weather(code = 66)))
        assertEquals(DrivingHazard.SEVERE, WeatherAlerts.assess(weather(code = 96)))
    }

    @Test
    fun galeWindIsSevereEvenWithClearSky() {
        val data = weather(code = 0, windKmh = 80.0)
        assertEquals(DrivingHazard.SEVERE, WeatherAlerts.assess(data))
        assertTrue(WeatherAlerts.isWindOnlySevere(data))
        assertEquals(DrivingHazard.NONE, WeatherAlerts.assess(weather(code = 0, windKmh = 61.0)))
    }

    @Test
    fun refreshUsesTenMinuteAgeBoundary() {
        val previous = weather()
        val now = previous.fetchedAtEpochMs
        assertFalse(WeatherRefreshPolicy.needsRefresh(previous, previous.location, now + WeatherRefreshPolicy.INTERVAL_MS - 1))
        assertTrue(WeatherRefreshPolicy.needsRefresh(previous, previous.location, now + WeatherRefreshPolicy.INTERVAL_MS))
        assertTrue(WeatherRefreshPolicy.needsRefresh(previous, previous.location, now, force = true))
        assertTrue(WeatherRefreshPolicy.needsRefresh(null, previous.location, now))
    }

    @Test
    fun refreshUsesTwentyFiveKilometreDistanceBoundary() {
        val previous = weather(location = WeatherLocation(0.0, 0.0))
        val now = previous.fetchedAtEpochMs
        assertFalse(
            WeatherRefreshPolicy.needsRefresh(previous, WeatherLocation(0.1, 0.0), now),
        )
        assertTrue(
            WeatherRefreshPolicy.needsRefresh(previous, WeatherLocation(0.3, 0.0), now),
        )
    }

    private fun weather(
        code: Int = 0,
        windKmh: Double = 5.0,
        location: WeatherLocation = WeatherLocation(41.9, 12.5),
    ) = WeatherData(
        location = location,
        temperatureCelsius = 12.0,
        code = code,
        windKmh = windKmh,
        fetchedAtEpochMs = 1_000_000,
    )
}
