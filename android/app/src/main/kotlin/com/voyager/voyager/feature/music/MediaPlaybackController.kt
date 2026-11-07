package com.voyager.voyager.feature.music

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@UnstableApi
class MediaPlaybackController(private val context: Context) {
    private var controller: MediaController? = null

    suspend fun play(
        tracks: List<MusicTrack>,
        startIndex: Int = 0,
        startPositionMs: Long = 0,
        playWhenReady: Boolean = true,
    ) {
        require(tracks.isNotEmpty()) { "No tracks supplied" }
        require(startIndex in tracks.indices) { "Invalid queue index" }
        require(startPositionMs >= 0) { "Invalid start position" }
        MediaCatalog.register(tracks)
        val items = tracks.map(::mediaItem)
        player().apply {
            setMediaItems(items, startIndex, startPositionMs)
            prepare()
            this.playWhenReady = playWhenReady
        }
    }

    suspend fun playPause() {
        player().let { if (it.isPlaying) it.pause() else it.play() }
    }

    suspend fun next() = player().seekToNextMediaItem()
    suspend fun previous() = player().seekToPreviousMediaItem()
    suspend fun stop() = player().apply {
        stop()
        clearMediaItems()
    }

    suspend fun setShuffle(enabled: Boolean) {
        player().shuffleModeEnabled = enabled
    }

    suspend fun setRepeat(mode: Int) {
        require(mode in Player.REPEAT_MODE_OFF..Player.REPEAT_MODE_ALL)
        player().repeatMode = mode
    }

    fun close() {
        controller?.release()
        controller = null
    }

    private suspend fun player(): MediaController {
        controller?.let { return it }
        val token = SessionToken(context, ComponentName(context, VoyagerMediaService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        return suspendCancellableCoroutine { continuation ->
            future.addListener(
                {
                    try {
                        val created = future.get()
                        controller = created
                        continuation.resume(created)
                    } catch (error: Throwable) {
                        continuation.resumeWithException(error)
                    }
                },
                ContextCompat.getMainExecutor(context),
            )
            continuation.invokeOnCancellation { future.cancel(true) }
        }
    }

    private fun mediaItem(track: MusicTrack): MediaItem = MediaItem.Builder()
        .setMediaId(MediaCatalog.mediaId(track))
        .setUri(track.streamUrl)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle(track.title)
                .setArtist(track.artist)
                .setAlbumTitle(track.album)
                .setArtworkUri(track.artworkUrl?.let(Uri::parse))
                .build(),
        )
        .build()
}
