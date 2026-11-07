package com.voyager.voyager.feature.weather

import com.voyager.voyager.core.network.BoundedHttpClient
import java.util.Locale
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONObject

class WeatherRepository(
    private val http: BoundedHttpClient = BoundedHttpClient(),
    private val cache: WeatherCache,
    private val forecastEndpoint: String = "https://api.open-meteo.com/v1/forecast",
    private val reverseEndpoint: String = "https://nominatim.openstreetmap.org/reverse",
) {
    fun cached(): WeatherData? = cache.load()

    suspend fun fetch(location: WeatherLocation, nowEpochMs: Long): WeatherData {
        val url = forecastEndpoint.toHttpUrl().newBuilder()
            .addQueryParameter("latitude", coordinate(location.latitude))
            .addQueryParameter("longitude", coordinate(location.longitude))
            .addQueryParameter("current", "temperature_2m,weather_code,wind_speed_10m")
            .addQueryParameter("wind_speed_unit", "kmh")
            .build()
        val json = http.getJsonObject(
            url.toString(),
            headers = mapOf("User-Agent" to USER_AGENT),
            maxBytes = 1024 * 1024,
            allowLanHttp = true,
        )
        return parseWeather(json, location, nowEpochMs).also(cache::save)
    }

    suspend fun placeName(location: WeatherLocation): String? {
        val url = reverseEndpoint.toHttpUrl().newBuilder()
            .addQueryParameter("lat", coordinate(location.latitude))
            .addQueryParameter("lon", coordinate(location.longitude))
            .addQueryParameter("format", "json")
            .addQueryParameter("addressdetails", "1")
            .addQueryParameter("zoom", "10")
            .build()
        val json = http.getJsonObject(
            url.toString(),
            headers = mapOf("User-Agent" to USER_AGENT),
            maxBytes = 256 * 1024,
            allowLanHttp = true,
        )
        return townFrom(json)
    }

    private fun coordinate(value: Double): String = String.format(Locale.US, "%.2f", value)

    companion object {
        private const val USER_AGENT = "Voyager/0.3.0"

        fun parseWeather(json: JSONObject, location: WeatherLocation, nowEpochMs: Long): WeatherData {
            val current = json.getJSONObject("current")
            return WeatherData(
                location = location,
                temperatureCelsius = current.getDouble("temperature_2m"),
                code = current.getInt("weather_code"),
                windKmh = current.getDouble("wind_speed_10m"),
                fetchedAtEpochMs = nowEpochMs,
            )
        }

        fun townFrom(json: JSONObject): String? {
            val address = json.optJSONObject("address") ?: return null
            return TOWN_KEYS.firstNotNullOfOrNull { key ->
                address.optString(key).trim().takeIf(String::isNotEmpty)
            }
        }

        private val TOWN_KEYS = listOf(
            "city",
            "town",
            "village",
            "municipality",
            "city_district",
            "county",
            "state",
        )
    }
}
