package com.voyager.voyager.core.plugin

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PhysicalKeyMapperTest {
    @Test
    fun mediaAndHeadsetKeysMapToTransportControls() {
        assertEquals(PhysicalButton.MEDIA_NEXT, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MEDIA_NEXT, false))
        assertEquals(PhysicalButton.MEDIA_PREVIOUS, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MEDIA_PREVIOUS, false))
        assertEquals(PhysicalButton.MEDIA_PLAY_PAUSE, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, false))
        assertEquals(PhysicalButton.MEDIA_PLAY_PAUSE, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_HEADSETHOOK, false))
        assertEquals(PhysicalButton.MEDIA_PLAY_PAUSE, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MEDIA_PLAY, false))
        assertEquals(PhysicalButton.MEDIA_PLAY_PAUSE, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MEDIA_PAUSE, false))
    }

    @Test
    fun volumeKeysAreOnlyRemappedByExplicitOptIn() {
        assertNull(PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_VOLUME_UP, false))
        assertNull(PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_VOLUME_DOWN, false))
        assertEquals(PhysicalButton.VOLUME_UP, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_VOLUME_UP, true))
        assertEquals(PhysicalButton.VOLUME_DOWN, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_VOLUME_DOWN, true))
    }

    @Test
    fun assistantAndMenuKeysAreMapped() {
        assertEquals(PhysicalButton.VOICE, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_VOICE_ASSIST, false))
        assertEquals(PhysicalButton.MENU, PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_MENU, false))
    }

    @Test
    fun unrelatedKeysAreLeftToAndroid() {
        assertNull(PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_BACK, false))
        assertNull(PhysicalKeyMapper.buttonFor(KeyEvent.KEYCODE_DPAD_UP, true))
    }
}
