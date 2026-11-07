package com.voyager.voyager.core.plugin

import android.view.KeyEvent

object PhysicalKeyMapper {
    fun buttonFor(keyCode: Int, remapVolumeKeys: Boolean): PhysicalButton? = when (keyCode) {
        KeyEvent.KEYCODE_VOLUME_UP -> PhysicalButton.VOLUME_UP.takeIf { remapVolumeKeys }
        KeyEvent.KEYCODE_VOLUME_DOWN -> PhysicalButton.VOLUME_DOWN.takeIf { remapVolumeKeys }
        KeyEvent.KEYCODE_MEDIA_NEXT -> PhysicalButton.MEDIA_NEXT
        KeyEvent.KEYCODE_MEDIA_PREVIOUS -> PhysicalButton.MEDIA_PREVIOUS
        KeyEvent.KEYCODE_MEDIA_PLAY,
        KeyEvent.KEYCODE_MEDIA_PAUSE,
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        KeyEvent.KEYCODE_HEADSETHOOK,
        -> PhysicalButton.MEDIA_PLAY_PAUSE
        KeyEvent.KEYCODE_VOICE_ASSIST -> PhysicalButton.VOICE
        KeyEvent.KEYCODE_MENU -> PhysicalButton.MENU
        else -> null
    }
}
