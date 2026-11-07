package com.voyager.voyager.feature.podcast

import org.junit.Assert.assertEquals
import org.junit.Test

class PodcastPlaybackPositionTest {
    @Test
    fun partiallyPlayedEpisodeResumesAtItsSavedPosition() {
        val position = PodcastPlaybackPosition(120_000, 1_800_000, 1)

        assertEquals(120_000, position.resumePositionMs())
    }

    @Test
    fun completedEpisodeStartsAgainFromTheBeginning() {
        val position = PodcastPlaybackPosition(1_795_000, 1_800_000, 1)

        assertEquals(0, position.resumePositionMs())
    }

    @Test
    fun unknownDurationDoesNotDiscardProgress() {
        val position = PodcastPlaybackPosition(120_000, 0, 1)

        assertEquals(120_000, position.resumePositionMs())
    }
}
