package com.voyager.voyager.feature.music

import com.voyager.voyager.core.network.BoundedHttpClient
import org.json.JSONObject

class JellyfinClient(
    endpoint: String,
    private val apiKey: String,
    private val userId: String,
    private val http: BoundedHttpClient = BoundedHttpClient(),
) {
    private val endpoint = endpoint.trimEnd('/')
    private val headers get() = mapOf("X-Emby-Token" to apiKey, "Accept" to "application/json")

    suspend fun ping() {
        request("/System/Info")
    }

    suspend fun recentAlbums(limit: Int = 60): List<MusicAlbum> = albums(
        mapOf(
            "IncludeItemTypes" to "MusicAlbum",
            "Recursive" to "true",
            "SortBy" to "DateCreated",
            "SortOrder" to "Descending",
            "Limit" to limit.coerceIn(1, 500).toString(),
        ),
    )

    suspend fun favouriteAlbums(limit: Int = 60): List<MusicAlbum> = albums(
        mapOf(
            "IncludeItemTypes" to "MusicAlbum",
            "Recursive" to "true",
            "Filters" to "IsFavorite",
            "Limit" to limit.coerceIn(1, 500).toString(),
        ),
    )

    suspend fun albumTracks(albumId: String): List<MusicTrack> = tracks(
        mapOf(
            "ParentId" to albumId,
            "IncludeItemTypes" to "Audio",
            "SortBy" to "ParentIndexNumber,IndexNumber,SortName",
        ),
    )

    suspend fun randomTracks(limit: Int = 50): List<MusicTrack> = tracks(
        mapOf(
            "IncludeItemTypes" to "Audio",
            "Recursive" to "true",
            "SortBy" to "Random",
            "Limit" to limit.coerceIn(1, 500).toString(),
        ),
    )

    suspend fun search(query: String): List<MusicTrack> {
        if (query.isBlank()) return emptyList()
        return tracks(
            mapOf(
                "IncludeItemTypes" to "Audio",
                "Recursive" to "true",
                "SearchTerm" to query.trim().take(200),
                "Limit" to "100",
            ),
        )
    }

    suspend fun playlists(): List<MusicPlaylist> =
        request(
            "/Users/$userId/Items",
            mapOf("IncludeItemTypes" to "Playlist", "Recursive" to "true", "SortBy" to "SortName"),
        ).objects("Items").map { item ->
            MusicPlaylist(
                id = item.getString("Id"),
                source = MusicSource.JELLYFIN,
                name = item.optString("Name"),
                trackCount = item.optInt("ChildCount"),
            )
        }

    suspend fun playlistTracks(id: String): List<MusicTrack> =
        request("/Playlists/$id/Items", mapOf("UserId" to userId)).objects("Items").map(::track)

    fun streamUrl(itemId: String): String = apiUrl(
        endpoint,
        "/Audio/$itemId/stream",
        mapOf("static" to "true"),
    ).toString()

    fun artworkUrl(itemId: String, size: Int = 512): String = apiUrl(
        endpoint,
        "/Items/$itemId/Images/Primary",
        mapOf("maxWidth" to size.toString(), "quality" to "90"),
    ).toString()

    private suspend fun albums(query: Map<String, String>): List<MusicAlbum> =
        request("/Users/$userId/Items", query).objects("Items").map { item ->
            val id = item.getString("Id")
            MusicAlbum(
                id = id,
                source = MusicSource.JELLYFIN,
                name = item.optString("Name"),
                artist = item.optString("AlbumArtist"),
                artworkUrl = artworkUrl(id),
            )
        }

    private suspend fun tracks(query: Map<String, String>): List<MusicTrack> =
        request("/Users/$userId/Items", query).objects("Items").map(::track)

    private suspend fun request(path: String, query: Map<String, String> = emptyMap()): JSONObject =
        http.getJsonObject(
            apiUrl(endpoint, path, query).toString(),
            headers = headers,
            maxBytes = 4 * 1024 * 1024,
            allowLanHttp = true,
        )

    private fun track(item: JSONObject): MusicTrack {
        val id = item.getString("Id")
        val firstArtist = item.optJSONArray("Artists")?.optString(0).orEmpty()
        return MusicTrack(
            id = id,
            source = MusicSource.JELLYFIN,
            title = item.optString("Name"),
            artist = item.optString("AlbumArtist").ifBlank { firstArtist },
            album = item.optString("Album"),
            durationMs = item.optLong("RunTimeTicks") / 10_000,
            streamUrl = streamUrl(id),
            artworkUrl = artworkUrl(item.optString("AlbumId").ifBlank { id }),
            requestHeaders = headers,
            trackNumber = item.optInt("IndexNumber"),
        )
    }
}
