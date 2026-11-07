package com.voyager.voyager.feature.music

import com.voyager.voyager.core.network.BoundedHttpClient
import org.json.JSONObject

class NavidromeClient(
    endpoint: String,
    username: String,
    password: String,
    private val http: BoundedHttpClient = BoundedHttpClient(),
) {
    private val api = SubsonicApi(endpoint, username, password)

    suspend fun ping() {
        http.getJsonObject(api.uri("ping"), maxBytes = 64 * 1024, allowLanHttp = true).requiredSubsonic()
    }

    suspend fun recentAlbums(size: Int = 60): List<MusicAlbum> =
        albums("getAlbumList2", mapOf("type" to "newest", "size" to size.coerceIn(1, 500).toString()), "albumList2")

    suspend fun starredAlbums(): List<MusicAlbum> = albums("getStarred2", emptyMap(), "starred2")

    suspend fun search(query: String): List<MusicTrack> {
        if (query.isBlank()) return emptyList()
        val response = request(
            "search3",
            mapOf("query" to query.trim().take(200), "songCount" to "100", "albumCount" to "0", "artistCount" to "0"),
        )
        return response.optJSONObject("searchResult3")?.objects("song").orEmpty().map(::track)
    }

    suspend fun albumTracks(albumId: String): List<MusicTrack> =
        request("getAlbum", mapOf("id" to albumId)).optJSONObject("album")?.objects("song").orEmpty().map(::track)

    suspend fun randomTracks(size: Int = 50): List<MusicTrack> =
        request("getRandomSongs", mapOf("size" to size.coerceIn(1, 500).toString()))
            .optJSONObject("randomSongs")?.objects("song").orEmpty().map(::track)

    suspend fun playlists(): List<MusicPlaylist> =
        request("getPlaylists").optJSONObject("playlists")?.objects("playlist").orEmpty().map { item ->
            MusicPlaylist(
                id = item.getString("id"),
                source = MusicSource.NAVIDROME,
                name = item.optString("name"),
                trackCount = item.optInt("songCount"),
            )
        }

    suspend fun playlistTracks(id: String): List<MusicTrack> =
        request("getPlaylist", mapOf("id" to id)).optJSONObject("playlist")?.objects("entry").orEmpty().map(::track)

    fun streamUrl(trackId: String): String = api.uri("stream", mapOf("id" to trackId))

    fun artworkUrl(coverId: String, size: Int = 512): String =
        api.uri("getCoverArt", mapOf("id" to coverId, "size" to size.coerceIn(64, 1024).toString()))

    private suspend fun albums(method: String, parameters: Map<String, String>, container: String): List<MusicAlbum> =
        request(method, parameters).optJSONObject(container)?.objects("album").orEmpty().map { item ->
            MusicAlbum(
                id = item.getString("id"),
                source = MusicSource.NAVIDROME,
                name = item.optString("name", item.optString("title")),
                artist = item.optString("artist"),
                artworkUrl = item.optString("coverArt").takeIf(String::isNotBlank)?.let(::artworkUrl),
            )
        }

    private suspend fun request(method: String, parameters: Map<String, String> = emptyMap()): JSONObject =
        http.getJsonObject(
            api.uri(method, parameters),
            maxBytes = 4 * 1024 * 1024,
            allowLanHttp = true,
        ).requiredSubsonic()

    private fun track(item: JSONObject): MusicTrack {
        val id = item.getString("id")
        return MusicTrack(
            id = id,
            source = MusicSource.NAVIDROME,
            title = item.optString("title"),
            artist = item.optString("artist"),
            album = item.optString("album"),
            durationMs = item.optLong("duration") * 1000,
            streamUrl = streamUrl(id),
            artworkUrl = item.optString("coverArt").takeIf(String::isNotBlank)?.let(::artworkUrl),
            trackNumber = item.optInt("track"),
        )
    }
}
