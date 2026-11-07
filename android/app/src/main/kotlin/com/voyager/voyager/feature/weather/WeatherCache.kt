package com.voyager.voyager.feature.weather

import android.content.Context
import org.json.JSONObject

interface WeatherCache {
    fun load(): WeatherData?
    fun save(data: WeatherData)
}

class SharedPreferencesWeatherCache(context: Context) : WeatherCache {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_weather",
        Context.MODE_PRIVATE,
    )

    @Synchronized
    override fun load(): WeatherData? {
        val raw = preferences.getString(KEY_LAST_READING, null) ?: return null
        return runCatching {
            val json = JSONObject(raw)
            WeatherData(
                location = WeatherLocation(
                    latitude = json.getDouble("latitude"),
                    longitude = json.getDouble("longitude"),
                ),
                temperatureCelsius = json.getDouble("temperatureCelsius"),
                code = json.getInt("code"),
                windKmh = json.getDouble("windKmh"),
                fetchedAtEpochMs = json.getLong("fetchedAtEpochMs"),
            )
        }.getOrNull()
    }

    @Synchronized
    override fun save(data: WeatherData) {
        val json = JSONObject()
            .put("latitude", data.location.latitude)
            .put("longitude", data.location.longitude)
            .put("temperatureCelsius", data.temperatureCelsius)
            .put("code", data.code)
            .put("windKmh", data.windKmh)
            .put("fetchedAtEpochMs", data.fetchedAtEpochMs)
        check(preferences.edit().putString(KEY_LAST_READING, json.toString()).commit()) {
            "Weather cache could not be saved"
        }
    }

    companion object {
        private const val KEY_LAST_READING = "last_reading_v1"
    }
}
