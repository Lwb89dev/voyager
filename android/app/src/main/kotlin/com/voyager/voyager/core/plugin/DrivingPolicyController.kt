package com.voyager.voyager.core.plugin

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class DrivingState { UNKNOWN, PARKED, MOVING }

class DrivingPolicyController(
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private var slowSinceEpochMs: Long? = null
    private val _state = MutableStateFlow(DrivingState.UNKNOWN)
    val state: StateFlow<DrivingState> = _state

    fun update(speedMetersPerSecond: Double?): DrivingState {
        val speed = speedMetersPerSecond?.takeIf { it.isFinite() && it >= 0 }
        if (speed == null) {
            slowSinceEpochMs = null
            return publish(DrivingState.UNKNOWN)
        }
        if (speed >= MOVING_SPEED) {
            slowSinceEpochMs = null
            return publish(DrivingState.MOVING)
        }
        if (speed > PARKED_SPEED) return _state.value

        val now = clock()
        val slowSince = slowSinceEpochMs ?: now.also { slowSinceEpochMs = it }
        if (now - slowSince < PARKED_HOLD_MS) {
            return if (_state.value == DrivingState.MOVING) _state.value else publish(DrivingState.UNKNOWN)
        }
        return publish(DrivingState.PARKED)
    }

    private fun publish(value: DrivingState): DrivingState {
        _state.value = value
        return value
    }

    companion object {
        const val PARKED_SPEED = 1.5
        const val MOVING_SPEED = 2.0
        const val PARKED_HOLD_MS = 10_000L
    }
}
