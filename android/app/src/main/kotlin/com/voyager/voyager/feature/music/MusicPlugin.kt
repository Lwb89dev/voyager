package com.voyager.voyager.feature.music

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.runtime.Composable
import androidx.media3.common.util.UnstableApi
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.PhysicalButton
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class MusicUiState(
    val backend: MusicBackend = MusicBackend.LOCAL,
    val albums: List<MusicAlbum> = emptyList(),
    val searchResults: List<MusicTrack>? = null,
    val loading: Boolean = false,
    val error: String? = null,
)

@UnstableApi
class MusicPlugin(
    context: Context,
    private val playback: MediaPlaybackController,
    private val configurationStore: MusicConfigurationStore,
    private val localRepository: MediaStoreAudioRepository,
    private val libraryFactory: (MusicConfiguration) -> MusicLibrary,
    private val requestAudioPermission: () -> Unit,
) : VoyagerPlugin() {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var library: MusicLibrary? = null
    private val _state = MutableStateFlow(MusicUiState())
    val state: StateFlow<MusicUiState> = _state
    val playbackState: StateFlow<PlaybackSnapshot> = PlaybackStateBus.state
    private val _parked = MutableStateFlow(false)
    val parked: StateFlow<Boolean> = _parked

    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_music,
        icon = Icons.Rounded.MusicNote,
        order = 1,
    )

    constructor(context: Context, requestAudioPermission: () -> Unit) : this(
        context = context,
        playback = MediaPlaybackController(context),
        configurationStore = MusicConfigurationStore(context),
        localRepository = MediaStoreAudioRepository(context),
        libraryFactory = { configuration -> musicLibraryFor(configuration, MediaStoreAudioRepository(context)) },
        requestAudioPermission = requestAudioPermission,
    )

    override suspend fun initialize() = reload()

    suspend fun reload() {
        _state.value = _state.value.copy(loading = true, error = null)
        try {
            val configuration = withContext(Dispatchers.IO) { configurationStore.load() }
            val selected = libraryFactory(configuration)
            library = selected
            val albums = withContext(Dispatchers.IO) { selected.albums() }
            _state.value = MusicUiState(backend = configuration.backend, albums = albums)
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            _state.value = _state.value.copy(
                loading = false,
                error = when (error) {
                    is SecurityException -> "Audio library permission is required"
                    else -> "Music library unavailable (${error::class.simpleName})"
                },
            )
        }
    }

    fun requestPermission() = requestAudioPermission()
    fun setParked(value: Boolean) { _parked.value = value }

    fun playAlbum(id: String) = scope.launch {
        runCatching { library?.albumTracks(id).orEmpty() }
            .onSuccess { if (it.isNotEmpty()) playback.play(it) }
            .onFailure { _state.value = _state.value.copy(error = "Album could not be loaded") }
    }

    fun playTrack(track: MusicTrack) = scope.launch { playback.play(listOf(track)) }

    fun shuffle() = scope.launch {
        _state.value = _state.value.copy(loading = true, error = null)
        try {
            val tracks = library?.randomTracks().orEmpty()
            if (tracks.isEmpty()) {
                _state.value = _state.value.copy(loading = false, error = "No playable tracks found")
            } else {
                playback.play(tracks.shuffled())
                _state.value = _state.value.copy(loading = false)
            }
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            _state.value = _state.value.copy(loading = false, error = "Playback could not be started")
        }
    }

    fun search(query: String) = scope.launch {
        if (query.isBlank()) {
            _state.value = _state.value.copy(searchResults = null)
            return@launch
        }
        _state.value = _state.value.copy(loading = true, error = null)
        try {
            val results = library?.search(query).orEmpty()
            _state.value = _state.value.copy(searchResults = results, loading = false)
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            _state.value = _state.value.copy(loading = false, error = "Search failed")
        }
    }

    fun playPause() = scope.launch { playback.playPause() }
    fun next() = scope.launch { playback.next() }
    fun previous() = scope.launch { playback.previous() }
    fun stop() = scope.launch { playback.stop() }
    fun toggleShuffle() = scope.launch { playback.setShuffle(!playbackState.value.shuffleEnabled) }
    fun cycleRepeat() = scope.launch {
        val nextMode = when (playbackState.value.repeatMode) {
            androidx.media3.common.Player.REPEAT_MODE_OFF -> androidx.media3.common.Player.REPEAT_MODE_ALL
            androidx.media3.common.Player.REPEAT_MODE_ALL -> androidx.media3.common.Player.REPEAT_MODE_ONE
            else -> androidx.media3.common.Player.REPEAT_MODE_OFF
        }
        playback.setRepeat(nextMode)
    }

    override fun onPhysicalButtonPress(button: PhysicalButton): Boolean {
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
    override fun FullscreenContent() = MusicScreen(this)

    override fun close() {
        scope.cancel()
        playback.close()
    }

    companion object { const val ID = "music" }
}
