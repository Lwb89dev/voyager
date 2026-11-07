package com.voyager.voyager.feature.music

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class EqualizerSettingsStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_music",
        Context.MODE_PRIVATE,
    )

    fun load(): EqualizerSettings {
        val raw = preferences.getString(KEY_SETTINGS, null) ?: return EqualizerSettings()
        val json = JSONObject(raw)
        val gains = json.optJSONArray("gains")?.let { array ->
            List(array.length()) { index -> array.getDouble(index) }
        }
        return EqualizerSettings(
            enabled = json.getBoolean("enabled"),
            preset = EqualizerPreset.valueOf(json.getString("preset")),
            gains = gains,
        )
    }

    fun save(settings: EqualizerSettings) {
        val json = JSONObject()
            .put("enabled", settings.enabled)
            .put("preset", settings.preset.name)
            .put("gains", settings.gains?.let(::JSONArray))
        check(preferences.edit().putString(KEY_SETTINGS, json.toString()).commit()) {
            "Equalizer settings could not be saved"
        }
    }

    private companion object {
        const val KEY_SETTINGS = "equalizer_v1"
    }
}
