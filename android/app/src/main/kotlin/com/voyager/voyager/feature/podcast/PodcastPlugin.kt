package com.voyager.voyager.feature.podcast

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Podcasts
import androidx.compose.runtime.Composable
import androidx.media3.common.util.UnstableApi
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.DrivingPolicy
import com.voyager.voyager.core.plugin.PhysicalButton
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin
import com.voyager.voyager.feature.music.MediaPlaybackController
import com.voyager.voyager.feature.music.MusicSource
import com.voyager.voyager.feature.music.PlaybackSnapshot
import com.voyager.voyager.feature.music.PlaybackStateBus
import java.io.File
import kotlin.math.abs
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

data class PodcastUiState(
    val subscriptions: List<PodcastSubscription> = emptyList(),
    val selected: PodcastSubscription? = null,
    val episodes: List<PodcastEpisode> = emptyList(),
    val episodesFromCache: Boolean = false,
    val directoryResults: List<PodcastSubscription>? = null,
    val loading: Boolean = false,
    val error: String? = null,
)

@UnstableApi
class PodcastPlugin(
    context: Context,
    private val repository: PodcastRepository,
    private val playback: MediaPlaybackController,
    private val progressStore: PodcastPlaybackStore,
) : VoyagerPlugin() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _state = MutableStateFlow(PodcastUiState())
    val state: StateFlow<PodcastUiState> = _state
    val playbackState: StateFlow<PlaybackSnapshot> = PlaybackStateBus.state
    private var playbackObserver: Job? = null
    private var lastPodcastPlayback: PlaybackSnapshot? = null
    private var lastSavedEpisodeId: String? = null
    private var lastSavedPositionMs = 0L

    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_podcasts,
        icon = Icons.Rounded.Podcasts,
        order = 2,
        drivingPolicy = DrivingPolicy.PARKED_ONLY,
    )

    constructor(context: Context) : this(
        context = context,
        repository = PodcastRepository(
            store = SharedPreferencesPodcastSubscriptionStore(context),
            cache = FilePodcastFeedCache(File(context.applicationContext.filesDir, "podcast-feeds")),
        ),
        playback = MediaPlaybackController(context),
        progressStore = SharedPreferencesPodcastPlaybackStore(context),
    )

    override suspend fun initialize() {
        if (playbackObserver == null) {
            playbackObserver = scope.launch {
                playbackState.collect { snapshot -> onPlaybackSnapshot(snapshot) }
            }
        }
        val subscriptions = withContext(Dispatchers.IO) { repository.subscriptions() }
        _state.value = _state.value.copy(subscriptions = subscriptions)
    }

    fun submit(query: String) {
        val value = query.trim()
        if (value.isEmpty()) return
        scope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            try {
                if (value.startsWith("https://") || value.startsWith("http://")) {
                    val podcast = withContext(Dispatchers.IO) { repository.describe(value) }
                    withContext(Dispatchers.IO) { repository.subscribe(podcast) }
                    refreshSubscriptions()
                    _state.value = _state.value.copy(loading = false, directoryResults = null)
                } else {
                    val results = withContext(Dispatchers.IO) { repository.search(value) }
                    _state.value = _state.value.copy(loading = false, directoryResults = results)
                }
            } catch (error: Throwable) {
                if (error is CancellationException) throw error
                _state.value = _state.value.copy(loading = false, error = "Podcast request failed")
            }
        }
    }

    fun subscribe(podcast: PodcastSubscription) = scope.launch {
        try {
            withContext(Dispatchers.IO) { repository.subscribe(podcast) }
            refreshSubscriptions()
            _state.value = _state.value.copy(directoryResults = null, error = null)
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            _state.value = _state.value.copy(error = "Subscription could not be saved")
        }
    }

    fun unsubscribe(feedUrl: String) = scope.launch {
        try {
            withContext(Dispatchers.IO) { repository.unsubscribe(feedUrl) }
            refreshSubscriptions()
            _state.value = _state.value.copy(
                selected = null,
                episodes = emptyList(),
                episodesFromCache = false,
                error = null,
            )
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            _state.value = _state.value.copy(error = "Subscription could not be removed")
        }
    }

    fun open(podcast: PodcastSubscription) = scope.launch {
        _state.value = _state.value.copy(
            selected = podcast,
            episodes = emptyList(),
            episodesFromCache = false,
            loading = true,
            error = null,
        )
        try {
            val page = withContext(Dispatchers.IO) { repository.episodePage(podcast) }
            if (_state.value.selected?.feedUrl == podcast.feedUrl) {
                _state.value = _state.value.copy(
                    episodes = page.episodes,
                    episodesFromCache = page.fromCache,
                    loading = false,
                )
            }
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            if (_state.value.selected?.feedUrl == podcast.feedUrl) {
                _state.value = _state.value.copy(loading = false, error = "Podcast feed could not be loaded")
            }
        }
    }

    fun closeEpisodes() {
        _state.value = _state.value.copy(
            selected = null,
            episodes = emptyList(),
            episodesFromCache = false,
            error = null,
        )
    }

    fun play(episode: PodcastEpisode) = scope.launch {
        try {
            val queue = _state.value.episodes.ifEmpty { listOf(episode) }
            val index = queue.indexOfFirst { it.guid == episode.guid }.coerceAtLeast(0)
            val startPosition = withContext(Dispatchers.IO) {
                progressStore.load(episode.guid)?.resumePositionMs()
            } ?: 0
            playback.play(
                tracks = queue.map(PodcastEpisode::toTrack),
                startIndex = index,
                startPositionMs = startPosition,
            )
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            _state.value = _state.value.copy(error = "Playback could not be started")
        }
    }

    fun playPause() = scope.launch { playback.playPause() }
    fun next() = scope.launch { playback.next() }
    fun previous() = scope.launch { playback.previous() }
    fun stop() = scope.launch { playback.stop() }

    override fun onPhysicalButtonPress(button: PhysicalButton): Boolean {
        if (playbackState.value.current?.source != MusicSource.PODCAST) return false
        when (button) {
            PhysicalButton.VOLUME_UP,
            PhysicalButton.MEDIA_NEXT,
            -> next()
            PhysicalButton.VOLUME_DOWN,
            PhysicalButton.MEDIA_PREVIOUS,
            -> previous()
            PhysicalButton.MEDIA_PLAY_PAUSE -> playPause()
            else -> return false
        }
        return true
    }

    @Composable
    override fun FullscreenContent() = PodcastScreen(this)

    override fun close() {
        playbackObserver?.cancel()
        lastPodcastPlayback?.let { snapshot ->
            runCatching { runBlocking(Dispatchers.IO) { writePlaybackPosition(snapshot) } }
        }
        scope.cancel()
        playback.close()
    }

    private suspend fun onPlaybackSnapshot(snapshot: PlaybackSnapshot) {
        val previous = lastPodcastPlayback
        val current = snapshot.current?.takeIf { it.source == MusicSource.PODCAST }
        if (previous?.current != null &&
            (previous.current?.id != current?.id || (previous.isPlaying && !snapshot.isPlaying))
        ) {
            persistPlayback(previous)
        }
        if (current != null && snapshot.isPlaying) {
            val sameEpisode = previous?.takeIf { it.current?.id == current.id }
            val seekedBack = sameEpisode != null && snapshot.positionMs + 1_000 < sameEpisode.positionMs
            val saveDue = lastSavedEpisodeId != current.id ||
                abs(snapshot.positionMs - lastSavedPositionMs) >= POSITION_SAVE_INTERVAL_MS
            if (sameEpisode == null || seekedBack || saveDue) persistPlayback(snapshot)
        }
        lastPodcastPlayback = if (current == null) null else snapshot
    }

    private suspend fun persistPlayback(snapshot: PlaybackSnapshot) {
        try {
            withContext(Dispatchers.IO) { writePlaybackPosition(snapshot) }
            lastSavedEpisodeId = snapshot.current?.id
            lastSavedPositionMs = snapshot.positionMs
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            _state.value = _state.value.copy(error = "Playback position could not be saved")
        }
    }

    private fun writePlaybackPosition(snapshot: PlaybackSnapshot) {
        val track = snapshot.current ?: return
        val position = PodcastPlaybackPosition(
            positionMs = snapshot.positionMs,
            durationMs = snapshot.durationMs,
            updatedAtEpochMs = 0,
        )
        progressStore.save(
            episodeId = track.id,
            position = position.copy(positionMs = position.resumePositionMs()),
        )
    }

    private suspend fun refreshSubscriptions() {
        val subscriptions = withContext(Dispatchers.IO) { repository.subscriptions() }
        _state.value = _state.value.copy(subscriptions = subscriptions)
    }

    companion object {
        const val ID = "podcast"
        private const val POSITION_SAVE_INTERVAL_MS = 10_000L
    }
}
