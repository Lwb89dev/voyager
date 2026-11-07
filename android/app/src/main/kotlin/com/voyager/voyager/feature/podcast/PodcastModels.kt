package com.voyager.voyager.feature.podcast

import com.voyager.voyager.feature.music.MusicSource
import com.voyager.voyager.feature.music.MusicTrack

data class PodcastSubscription(
    val feedUrl: String,
    val title: String,
    val imageUrl: String? = null,
)

data class PodcastEpisode(
    val guid: String,
    val title: String,
    val podcastTitle: String,
    val audioUrl: String,
    val durationMs: Long = 0,
    val publishedEpochMs: Long? = null,
    val imageUrl: String? = null,
) {
    fun toTrack() = MusicTrack(
        id = guid,
        source = MusicSource.PODCAST,
        title = title,
        artist = podcastTitle,
        album = podcastTitle,
        durationMs = durationMs,
        streamUrl = audioUrl,
        artworkUrl = imageUrl,
    )
}

data class PodcastFeed(
    val title: String,
    val imageUrl: String?,
    val episodes: List<PodcastEpisode>,
)

data class PodcastEpisodePage(
    val episodes: List<PodcastEpisode>,
    val fromCache: Boolean,
)
