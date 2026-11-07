package com.voyager.voyager.feature.music

import android.net.Uri
import java.util.concurrent.ConcurrentHashMap

internal object MediaCatalog {
    private val tracks = ConcurrentHashMap<String, MusicTrack>()
    private val headers = ConcurrentHashMap<String, Map<String, String>>()

    private const val MAX_TRACKS = 1_000

    fun mediaId(track: MusicTrack): String = "${track.source.name}:${track.id}"

    fun register(items: List<MusicTrack>) {
        items.forEach { track ->
            tracks[mediaId(track)] = track
            headers[track.streamUrl] = track.requestHeaders
        }
        if (tracks.size > MAX_TRACKS) {
            tracks.keys.take(tracks.size - MAX_TRACKS).forEach(tracks::remove)
        }
        if (headers.size > MAX_TRACKS) {
            headers.keys.take(headers.size - MAX_TRACKS).forEach(headers::remove)
        }
    }

    fun track(mediaId: String): MusicTrack? = tracks[mediaId]
    fun headers(uri: Uri): Map<String, String> = headers[uri.toString()].orEmpty()
    fun clear() {
        tracks.clear()
        headers.clear()
    }
}
