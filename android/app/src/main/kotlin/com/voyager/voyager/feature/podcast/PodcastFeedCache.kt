package com.voyager.voyager.feature.podcast

import java.io.File
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject

interface PodcastFeedCache {
    fun load(feedUrl: String): PodcastFeed?
    fun save(feedUrl: String, feed: PodcastFeed)
    fun remove(feedUrl: String)
}

class FilePodcastFeedCache(private val directory: File) : PodcastFeedCache {
    @Synchronized
    override fun load(feedUrl: String): PodcastFeed? {
        val file = cacheFile(feedUrl)
        if (!file.isFile || file.length() > MAX_CACHE_FILE_BYTES) return null
        return runCatching {
            val json = JSONObject(file.readText(Charsets.UTF_8))
            require(json.getString("feedUrl") == feedUrl)
            PodcastFeed(
                title = json.getString("title"),
                imageUrl = json.optString("imageUrl").takeIf(String::isNotBlank),
                episodes = decodeEpisodes(json.getJSONArray("episodes")),
            )
        }.getOrNull()
    }

    @Synchronized
    override fun save(feedUrl: String, feed: PodcastFeed) {
        check(directory.isDirectory || directory.mkdirs()) { "Podcast cache directory is unavailable" }
        val target = cacheFile(feedUrl)
        val temporary = File(directory, "${target.name}.tmp")
        val json = JSONObject()
            .put("feedUrl", feedUrl)
            .put("title", feed.title)
            .put("imageUrl", feed.imageUrl)
            .put("episodes", encodeEpisodes(feed.episodes))
        try {
            temporary.writeText(json.toString(), Charsets.UTF_8)
            try {
                Files.move(
                    temporary.toPath(),
                    target.toPath(),
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING,
                )
            } catch (_: AtomicMoveNotSupportedException) {
                Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
        } finally {
            temporary.delete()
        }
        prune()
    }

    @Synchronized
    override fun remove(feedUrl: String) {
        cacheFile(feedUrl).delete()
    }

    private fun cacheFile(feedUrl: String): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(feedUrl.toByteArray(Charsets.UTF_8))
        val name = digest.joinToString(separator = "") { "%02x".format(it) }
        return File(directory, "$name.json")
    }

    private fun prune() {
        val files = directory.listFiles { file -> file.isFile && file.name.endsWith(".json") }
            ?.sortedByDescending(File::lastModified)
            .orEmpty()
        files.drop(MAX_CACHED_FEEDS).forEach { it.delete() }
    }

    private fun encodeEpisodes(episodes: List<PodcastEpisode>): JSONArray = JSONArray().apply {
        episodes.forEach { episode ->
            put(
                JSONObject()
                    .put("guid", episode.guid)
                    .put("title", episode.title)
                    .put("podcastTitle", episode.podcastTitle)
                    .put("audioUrl", episode.audioUrl)
                    .put("durationMs", episode.durationMs)
                    .put("publishedEpochMs", episode.publishedEpochMs)
                    .put("imageUrl", episode.imageUrl),
            )
        }
    }

    private fun decodeEpisodes(array: JSONArray): List<PodcastEpisode> = buildList {
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val guid = item.optString("guid").trim()
            val audioUrl = item.optString("audioUrl").trim()
            if (guid.isEmpty() || audioUrl.isEmpty()) continue
            add(
                PodcastEpisode(
                    guid = guid,
                    title = item.optString("title").ifBlank { guid },
                    podcastTitle = item.optString("podcastTitle"),
                    audioUrl = audioUrl,
                    durationMs = item.optLong("durationMs").coerceAtLeast(0),
                    publishedEpochMs = item.optLong("publishedEpochMs", 0).takeIf { it > 0 },
                    imageUrl = item.optString("imageUrl").takeIf(String::isNotBlank),
                ),
            )
        }
    }

    companion object {
        private const val MAX_CACHED_FEEDS = 25
        private const val MAX_CACHE_FILE_BYTES = 4 * 1024 * 1024
    }
}
