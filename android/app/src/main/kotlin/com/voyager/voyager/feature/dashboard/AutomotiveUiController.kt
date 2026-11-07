package com.voyager.voyager.feature.dashboard

import android.content.Context
import app.roadstr.core.time.SolarTimes
import app.roadstr.core.time.SunCalc
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.PI
import kotlin.math.sin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class AutomotiveUiState(
    val keepAwake: Boolean = true,
    val nightDimming: Boolean = true,
    val isNight: Boolean = false,
) {
    val dimOpacity: Float
        get() = NightDimmingPolicy.dimOpacity(nightDimming, isNight)
}

object NightDimmingPolicy {
    const val NIGHT_OPACITY = 0.65f

    fun dimOpacity(enabled: Boolean, isNight: Boolean): Float =
        if (enabled && isNight) NIGHT_OPACITY else 0f

    fun isAfterDark(now: Instant, times: SolarTimes, latitude: Double): Boolean {
        val rise = times.rise
        val set = times.set
        if (rise == null && set == null) {
            val polarDay = (latitude >= 0) == (solarDeclination(now.atZone(ZoneOffset.UTC).toLocalDate()) >= 0)
            return !polarDay
        }
        if (set == null) return false
        if (rise == null) return true
        return now.isAfter(set) || now.isBefore(rise)
    }

    private fun solarDeclination(date: LocalDate): Double {
        val angle = 2 * PI * (284 + date.dayOfYear) / 365.0
        return 23.44 * sin(angle)
    }
}

class AutomotiveUiController(
    context: Context,
    private val clock: () -> Instant = Instant::now,
) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_automotive",
        Context.MODE_PRIVATE,
    )
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var latitude: Double? = null
    private var longitude: Double? = null
    private val _state = MutableStateFlow(
        AutomotiveUiState(
            keepAwake = preferences.getBoolean(KEY_KEEP_AWAKE, true),
            nightDimming = preferences.getBoolean(KEY_NIGHT_DIMMING, true),
        ),
    )
    val state: StateFlow<AutomotiveUiState> = _state

    fun initialize() {
        scope.launch {
            evaluate()
            while (isActive) {
                delay(EVALUATION_INTERVAL_MS)
                evaluate()
            }
        }
    }

    fun setKeepAwake(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_KEEP_AWAKE, enabled).apply()
        _state.value = _state.value.copy(keepAwake = enabled)
    }

    fun setNightDimming(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_NIGHT_DIMMING, enabled).apply()
        _state.value = _state.value.copy(nightDimming = enabled)
    }

    fun setLocation(latitude: Double, longitude: Double) {
        require(latitude.isFinite() && latitude in -90.0..90.0)
        require(longitude.isFinite() && longitude in -180.0..180.0)
        this.latitude = latitude
        this.longitude = longitude
        evaluate()
    }

    fun evaluate() {
        val latitude = latitude ?: return
        val longitude = longitude ?: return
        val now = clock()
        val times = SunCalc.sunTimes(latitude, longitude, now.atZone(ZoneOffset.UTC).toLocalDate())
        val night = NightDimmingPolicy.isAfterDark(now, times, latitude)
        if (night != _state.value.isNight) _state.value = _state.value.copy(isNight = night)
    }

    fun close() = scope.cancel()

    companion object {
        private const val KEY_KEEP_AWAKE = "keep_awake"
        private const val KEY_NIGHT_DIMMING = "night_dimming"
        private const val EVALUATION_INTERVAL_MS = 15 * 60 * 1_000L
    }
}
