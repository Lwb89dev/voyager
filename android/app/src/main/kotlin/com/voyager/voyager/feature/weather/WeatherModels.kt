package com.voyager.voyager.feature.weather

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

data class WeatherLocation(
    val latitude: Double,
    val longitude: Double,
) {
    init {
        require(latitude.isFinite() && latitude in -90.0..90.0)
        require(longitude.isFinite() && longitude in -180.0..180.0)
    }
}

data class WeatherData(
    val location: WeatherLocation,
    val temperatureCelsius: Double,
    val code: Int,
    val windKmh: Double,
    val fetchedAtEpochMs: Long,
) {
    init {
        require(temperatureCelsius.isFinite() && temperatureCelsius in -100.0..70.0)
        require(code in 0..99)
        require(windKmh.isFinite() && windKmh in 0.0..500.0)
        require(fetchedAtEpochMs >= 0)
    }
}

enum class DrivingHazard { NONE, CAUTION, SEVERE }

object WeatherAlerts {
    const val GALE_KMH = 62.0

    fun assess(data: WeatherData): DrivingHazard = when {
        data.code in SEVERE_CODES || data.windKmh >= GALE_KMH -> DrivingHazard.SEVERE
        data.code in CAUTION_CODES -> DrivingHazard.CAUTION
        else -> DrivingHazard.NONE
    }

    fun isWindOnlySevere(data: WeatherData): Boolean =
        data.windKmh >= GALE_KMH && data.code !in SEVERE_CODES

    private val SEVERE_CODES = setOf(56, 57, 66, 67, 75, 86, 95, 96, 99)
    private val CAUTION_CODES = setOf(45, 48) +
        (51..65) + (71..77) + (80..85)
}

object WeatherRefreshPolicy {
    const val INTERVAL_MS = 10 * 60 * 1_000L
    const val DISTANCE_METERS = 25_000.0

    fun needsRefresh(
        previous: WeatherData?,
        location: WeatherLocation,
        nowEpochMs: Long,
        force: Boolean = false,
    ): Boolean {
        if (force || previous == null) return true
        if (nowEpochMs - previous.fetchedAtEpochMs >= INTERVAL_MS) return true
        return distanceMeters(previous.location, location) >= DISTANCE_METERS
    }

    fun distanceMeters(left: WeatherLocation, right: WeatherLocation): Double {
        val lat1 = Math.toRadians(left.latitude)
        val lat2 = Math.toRadians(right.latitude)
        val deltaLat = lat2 - lat1
        val deltaLon = Math.toRadians(right.longitude - left.longitude)
        val a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return EARTH_RADIUS_METERS * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private const val EARTH_RADIUS_METERS = 6_371_000.0
}
