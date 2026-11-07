package com.voyager.voyager.feature.music

import org.junit.Assert.assertEquals
import org.junit.Test

class EqualizerPresetsTest {
    @Test
    fun preservesEndpointsAndFiveBandCurves() {
        EqualizerPreset.entries.forEach { preset ->
            assertEquals(preset.anchors.first(), preset.shape(5).first(), 0.0001)
            assertEquals(preset.anchors.last(), preset.shape(5).last(), 0.0001)
            assertEquals(5, preset.shape(5).size)
        }
    }

    @Test
    fun resamplesAcrossDeviceBandCounts() {
        assertEquals(listOf(0.0, 0.5, 1.0), EqualizerPreset.resample(listOf(0.0, 1.0), 3))
        assertEquals(listOf(0.35), EqualizerPreset.ROCK.shape(1))
        assertEquals(emptyList<Double>(), EqualizerPreset.ROCK.shape(0))
    }

    @Test
    fun scalesPositiveAndNegativeRangesIndependently() {
        val gains = EqualizerPreset.ROCK.gains(5, -12.0, 15.0)
        assertEquals(5.25, gains[0], 0.0001)
        assertEquals(-5.28, gains[1], 0.0001)
        assertEquals(9.45, gains[4], 0.0001)
    }
}
