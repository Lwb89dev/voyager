package com.voyager.voyager.feature.music

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class MediaCatalogTest {
    @After
    fun tearDown() = MediaCatalog.clear()

    @Test
    fun mediaIdsKeepSourcesDistinct() {
        val local = track(MusicSource.LOCAL)
        val remote = track(MusicSource.NAVIDROME)

        MediaCatalog.register(listOf(local, remote))

        assertNotEquals(MediaCatalog.mediaId(local), MediaCatalog.mediaId(remote))
        assertEquals(local, MediaCatalog.track(MediaCatalog.mediaId(local)))
        assertEquals(remote, MediaCatalog.track(MediaCatalog.mediaId(remote)))
    }

    @Test
    fun latestQueueEntryWithSameSourceAndIdWins() {
        val original = track(MusicSource.JELLYFIN, title = "Original")
        val replacement = track(MusicSource.JELLYFIN, title = "Replacement")

        MediaCatalog.register(listOf(original))
        MediaCatalog.register(listOf(replacement))

        assertEquals("Replacement", MediaCatalog.track(MediaCatalog.mediaId(replacement))?.title)
    }

    private fun track(source: MusicSource, title: String = "Track") = MusicTrack(
        id = "shared-id",
        source = source,
        title = title,
        streamUrl = "https://example.com/${source.name}/shared-id",
    )
}
