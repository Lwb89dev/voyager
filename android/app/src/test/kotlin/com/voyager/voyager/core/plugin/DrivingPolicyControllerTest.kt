package com.voyager.voyager.core.plugin

import org.junit.Assert.assertEquals
import org.junit.Test

class DrivingPolicyControllerTest {
    private var now = 100_000L
    private val controller = DrivingPolicyController { now }

    @Test
    fun missingOrInvalidSpeedIsUnknown() {
        assertEquals(DrivingState.UNKNOWN, controller.update(null))
        assertEquals(DrivingState.UNKNOWN, controller.update(Double.NaN))
        assertEquals(DrivingState.UNKNOWN, controller.update(-1.0))
    }

    @Test
    fun stationarySpeedMustBeHeldBeforeParkedActionsUnlock() {
        assertEquals(DrivingState.UNKNOWN, controller.update(0.0))
        now += DrivingPolicyController.PARKED_HOLD_MS - 1
        assertEquals(DrivingState.UNKNOWN, controller.update(0.0))
        now += 1
        assertEquals(DrivingState.PARKED, controller.update(0.0))
    }

    @Test
    fun recentMovementDoesNotInstantlyUnlockParkedActions() {
        assertEquals(DrivingState.MOVING, controller.update(8.0))
        assertEquals(DrivingState.MOVING, controller.update(0.0))
        now += DrivingPolicyController.PARKED_HOLD_MS
        assertEquals(DrivingState.PARKED, controller.update(0.0))
    }

    @Test
    fun hysteresisAvoidsStateFlappingAroundThreshold() {
        assertEquals(DrivingState.UNKNOWN, controller.update(0.0))
        now += DrivingPolicyController.PARKED_HOLD_MS
        assertEquals(DrivingState.PARKED, controller.update(0.0))
        assertEquals(DrivingState.PARKED, controller.update(1.7))
        assertEquals(DrivingState.MOVING, controller.update(2.0))
    }

    @Test
    fun losingFixClearsParkedState() {
        assertEquals(DrivingState.UNKNOWN, controller.update(0.0))
        now += DrivingPolicyController.PARKED_HOLD_MS
        assertEquals(DrivingState.PARKED, controller.update(0.0))
        assertEquals(DrivingState.UNKNOWN, controller.update(null))
    }
}
