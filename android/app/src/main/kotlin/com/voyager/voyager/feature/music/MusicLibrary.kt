package com.voyager.voyager.feature.music

interface MusicLibrary {
    suspend fun albums(): List<MusicAlbum>
    suspend fun albumTracks(id: String): List<MusicTrack>
    suspend fun randomTracks(): List<MusicTrack>
    suspend fun search(query: String): List<MusicTrack>
    suspend fun playlists(): List<MusicPlaylist> = emptyList()
    suspend fun playlistTracks(id: String): List<MusicTrack> = emptyList()
}

class LocalMusicLibrary(private val repository: MediaStoreAudioRepository) : MusicLibrary {
    override suspend fun albums(): List<MusicAlbum> = repository.albums()

    override suspend fun albumTracks(id: String): List<MusicTrack> = repository.tracks()
        .filter { "${it.album}|${it.artist}" == id }

    override suspend fun randomTracks(): List<MusicTrack> = repository.tracks().shuffled().take(50)

    override suspend fun search(query: String): List<MusicTrack> {
        val needle = query.trim().lowercase()
        if (needle.isEmpty()) return emptyList()
        return repository.tracks().filter {
            it.title.lowercase().contains(needle) ||
                it.artist.lowercase().contains(needle) ||
                it.album.lowercase().contains(needle)
        }.take(100)
    }
}

class NavidromeMusicLibrary(private val client: NavidromeClient) : MusicLibrary {
    override suspend fun albums() = client.recentAlbums()
    override suspend fun albumTracks(id: String) = client.albumTracks(id)
    override suspend fun randomTracks() = client.randomTracks()
    override suspend fun search(query: String) = client.search(query)
    override suspend fun playlists() = client.playlists()
    override suspend fun playlistTracks(id: String) = client.playlistTracks(id)
}

class JellyfinMusicLibrary(private val client: JellyfinClient) : MusicLibrary {
    override suspend fun albums() = client.recentAlbums()
    override suspend fun albumTracks(id: String) = client.albumTracks(id)
    override suspend fun randomTracks() = client.randomTracks()
    override suspend fun search(query: String) = client.search(query)
    override suspend fun playlists() = client.playlists()
    override suspend fun playlistTracks(id: String) = client.playlistTracks(id)
}

fun musicLibraryFor(configuration: MusicConfiguration, repository: MediaStoreAudioRepository): MusicLibrary =
    when (configuration.backend) {
        MusicBackend.LOCAL -> LocalMusicLibrary(repository)
        MusicBackend.NAVIDROME -> NavidromeMusicLibrary(
            NavidromeClient(configuration.endpoint, configuration.username, configuration.password),
        )
        MusicBackend.JELLYFIN -> JellyfinMusicLibrary(
            JellyfinClient(configuration.endpoint, configuration.password, configuration.userId),
        )
    }
