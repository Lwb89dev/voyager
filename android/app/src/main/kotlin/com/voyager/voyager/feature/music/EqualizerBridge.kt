package com.voyager.voyager.feature.music

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class EqualizerSettings(
    val enabled: Boolean = false,
    val preset: EqualizerPreset = EqualizerPreset.FLAT,
    val gains: List<Double>? = null,
)

object EqualizerBridge {
    private val _settings = MutableStateFlow(EqualizerSettings())
    val settings: StateFlow<EqualizerSettings> = _settings

    fun update(settings: EqualizerSettings) {
        _settings.value = settings
    }
}
