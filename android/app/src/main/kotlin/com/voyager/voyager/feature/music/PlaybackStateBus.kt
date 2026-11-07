package com.voyager.voyager.feature.music

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class PlaybackSnapshot(
    val current: MusicTrack? = null,
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val isPlaying: Boolean = false,
    val isLoading: Boolean = false,
    val shuffleEnabled: Boolean = false,
    val repeatMode: Int = 0,
)

object PlaybackStateBus {
    private val _state = MutableStateFlow(PlaybackSnapshot())
    val state: StateFlow<PlaybackSnapshot> = _state

    internal fun publish(snapshot: PlaybackSnapshot) {
        _state.value = snapshot
    }
}
