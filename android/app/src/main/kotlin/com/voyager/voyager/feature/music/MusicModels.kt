package com.voyager.voyager.feature.music

enum class MusicSource { LOCAL, NAVIDROME, JELLYFIN, PODCAST }

data class MusicTrack(
    val id: String,
    val source: MusicSource,
    val title: String,
    val artist: String = "",
    val album: String = "",
    val durationMs: Long = 0,
    val streamUrl: String,
    val artworkUrl: String? = null,
    val requestHeaders: Map<String, String> = emptyMap(),
    val trackNumber: Int = 0,
)

data class MusicAlbum(
    val id: String,
    val source: MusicSource,
    val name: String,
    val artist: String = "",
    val artworkUrl: String? = null,
)

data class MusicPlaylist(
    val id: String,
    val source: MusicSource,
    val name: String,
    val trackCount: Int = 0,
)
