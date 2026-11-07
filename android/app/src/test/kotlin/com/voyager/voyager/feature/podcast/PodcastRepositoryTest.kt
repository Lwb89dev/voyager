package com.voyager.voyager.feature.podcast

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PodcastRepositoryTest {
    @Test
    fun privateLanFeedCanBeDescribedSubscribedAndRead() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody(FEED))
        server.enqueue(MockResponse().setBody(FEED))
        server.start()
        val store = MemoryStore()
        val repository = PodcastRepository(store = store, cache = MemoryCache())
        val subscription = repository.describe(server.url("/feed.xml").toString())
        repository.subscribe(subscription)
        repository.subscribe(subscription)

        assertEquals("LAN show", subscription.title)
        assertEquals(1, repository.subscriptions().size)
        assertEquals("Episode", repository.episodePage(subscription).episodes.single().title)
        assertEquals("/feed.xml", server.takeRequest().path)
        repository.unsubscribe(subscription.feedUrl)
        assertEquals(emptyList<PodcastSubscription>(), repository.subscriptions())
        server.shutdown()
    }

    @Test
    fun networkFailureReturnsTheLastGoodFeedWithExplicitCacheState() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody(FEED))
        server.start()
        val subscription = PodcastSubscription(server.url("/feed.xml").toString(), "LAN show")
        val repository = PodcastRepository(store = MemoryStore(), cache = MemoryCache())

        val online = repository.episodePage(subscription)
        server.shutdown()
        val offline = repository.episodePage(subscription)

        assertFalse(online.fromCache)
        assertTrue(offline.fromCache)
        assertEquals(online.episodes, offline.episodes)
    }

    private class MemoryStore : PodcastSubscriptionStore {
        private var subscriptions = listOf<PodcastSubscription>()
        override fun load(): List<PodcastSubscription> = subscriptions
        override fun save(subscriptions: List<PodcastSubscription>) {
            this.subscriptions = subscriptions
        }
    }

    private class MemoryCache : PodcastFeedCache {
        private val feeds = mutableMapOf<String, PodcastFeed>()
        override fun load(feedUrl: String): PodcastFeed? = feeds[feedUrl]
        override fun save(feedUrl: String, feed: PodcastFeed) {
            feeds[feedUrl] = feed
        }
        override fun remove(feedUrl: String) {
            feeds.remove(feedUrl)
        }
    }

    private companion object {
        val FEED = """
            <rss><channel><title>LAN show</title>
              <item><title>Episode</title><enclosure url="https://example.com/episode.mp3" /></item>
            </channel></rss>
        """.trimIndent()
    }
}
