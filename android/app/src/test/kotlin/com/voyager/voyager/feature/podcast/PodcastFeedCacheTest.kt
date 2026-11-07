package com.voyager.voyager.feature.podcast

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PodcastFeedCacheTest {
    @get:Rule
    val temporary = TemporaryFolder()

    @Test
    fun feedSurvivesReopeningTheCache() {
        val directory = temporary.newFolder("podcasts")
        val feed = PodcastFeed(
            title = "Show",
            imageUrl = "https://example.com/show.jpg",
            episodes = listOf(
                PodcastEpisode(
                    guid = "episode-1",
                    title = "First",
                    podcastTitle = "Show",
                    audioUrl = "https://example.com/first.mp3",
                    durationMs = 1_800_000,
                    publishedEpochMs = 1_700_000_000_000,
                    imageUrl = "https://example.com/first.jpg",
                ),
            ),
        )
        FilePodcastFeedCache(directory).save(FEED_URL, feed)

        assertEquals(feed, FilePodcastFeedCache(directory).load(FEED_URL))
    }

    @Test
    fun malformedCacheIsNotReturnedAsAValidFeed() {
        val directory = temporary.newFolder("podcasts")
        val cache = FilePodcastFeedCache(directory)
        cache.save(FEED_URL, PodcastFeed("Show", null, emptyList()))
        directory.listFiles().orEmpty().single { it.extension == "json" }.writeText("not json")

        assertNull(cache.load(FEED_URL))
    }

    @Test
    fun removingASubscriptionRemovesOnlyItsOwnCache() {
        val directory = temporary.newFolder("podcasts")
        val cache = FilePodcastFeedCache(directory)
        cache.save(FEED_URL, PodcastFeed("One", null, emptyList()))
        cache.save(OTHER_FEED_URL, PodcastFeed("Two", null, emptyList()))

        cache.remove(FEED_URL)

        assertNull(cache.load(FEED_URL))
        assertEquals("Two", cache.load(OTHER_FEED_URL)?.title)
    }

    private companion object {
        const val FEED_URL = "https://example.com/feed.xml"
        const val OTHER_FEED_URL = "https://example.org/feed.xml"
    }
}
