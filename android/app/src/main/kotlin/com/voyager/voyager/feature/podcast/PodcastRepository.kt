package com.voyager.voyager.feature.podcast

import com.voyager.voyager.core.network.BoundedHttpClient
import com.voyager.voyager.core.network.ServerUrlPolicy
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl

class PodcastRepository(
    private val http: BoundedHttpClient = BoundedHttpClient(),
    private val store: PodcastSubscriptionStore,
    private val cache: PodcastFeedCache,
    private val parser: PodcastFeedParser = PodcastFeedParser(),
) {
    fun subscriptions(): List<PodcastSubscription> = store.load()

    fun subscribe(podcast: PodcastSubscription) {
        val current = store.load()
        if (current.any { it.feedUrl == podcast.feedUrl }) return
        store.save(current + podcast)
    }

    fun unsubscribe(feedUrl: String) {
        store.save(store.load().filterNot { it.feedUrl == feedUrl })
        cache.remove(feedUrl)
    }

    suspend fun describe(feedUrl: String): PodcastSubscription {
        val normalized = ServerUrlPolicy.requireAllowed(feedUrl, allowLanHttp = true).toString()
        val feed = loadFeed(normalized)
        return PodcastSubscription(normalized, feed.title, feed.imageUrl)
    }

    suspend fun episodePage(
        subscription: PodcastSubscription,
        maxEpisodes: Int = 50,
    ): PodcastEpisodePage {
        val normalized = ServerUrlPolicy.requireAllowed(subscription.feedUrl, allowLanHttp = true).toString()
        return try {
            PodcastEpisodePage(
                episodes = loadFeed(normalized, subscription.title, maxEpisodes).episodes,
                fromCache = false,
            )
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            val cached = cache.load(normalized) ?: throw error
            PodcastEpisodePage(cached.episodes, fromCache = true)
        }
    }

    suspend fun search(term: String, limit: Int = 25): List<PodcastSubscription> {
        val query = term.trim()
        if (query.isEmpty()) return emptyList()
        require(limit in 1..50) { "Invalid search limit" }
        val url = DIRECTORY_URL.toHttpUrl().newBuilder()
            .addQueryParameter("media", "podcast")
            .addQueryParameter("term", query)
            .addQueryParameter("limit", limit.toString())
            .build()
        val result = http.getJsonObject(url.toString(), maxBytes = 2 * 1024 * 1024)
        val items = result.optJSONArray("results") ?: return emptyList()
        return buildList {
            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                val feedUrl = item.optString("feedUrl").trim()
                if (feedUrl.isEmpty() || runCatching { ServerUrlPolicy.requireAllowed(feedUrl) }.isFailure) continue
                add(
                    PodcastSubscription(
                        feedUrl = feedUrl,
                        title = item.optString("trackName").ifBlank { item.optString("collectionName") }
                            .ifBlank { feedUrl },
                        imageUrl = item.optString("artworkUrl100").ifBlank { item.optString("artworkUrl60") }
                            .takeIf(String::isNotBlank),
                    ),
                )
            }
        }.distinctBy(PodcastSubscription::feedUrl).take(limit)
    }

    private suspend fun loadFeed(
        url: String,
        fallbackTitle: String = "",
        maxEpisodes: Int = 50,
    ): PodcastFeed {
        val bytes = http.getBytes(
            ServerUrlPolicy.requireAllowed(url, allowLanHttp = true).toString(),
            maxBytes = MAX_FEED_BYTES,
            allowLanHttp = true,
        )
        val feed = withContext(Dispatchers.Default) { parser.parse(bytes, fallbackTitle, maxEpisodes) }
        runCatching { cache.save(url, feed) }
        return feed
    }

    companion object {
        const val MAX_FEED_BYTES = 20 * 1024 * 1024
        private const val DIRECTORY_URL = "https://itunes.apple.com/search"
    }
}
