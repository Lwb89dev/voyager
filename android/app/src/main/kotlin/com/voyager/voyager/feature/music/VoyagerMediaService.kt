package com.voyager.voyager.feature.music

import android.media.audiofx.Equalizer
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@UnstableApi
class VoyagerMediaService : MediaSessionService() {
    private lateinit var player: ExoPlayer
    private lateinit var session: MediaSession
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var positionJob: Job? = null
    private var equalizer: Equalizer? = null
    private var equalizerSessionId = C.AUDIO_SESSION_ID_UNSET
    private lateinit var equalizerSettingsStore: EqualizerSettingsStore

    override fun onCreate() {
        super.onCreate()
        val http = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(false)
            .setConnectTimeoutMs(8_000)
            .setReadTimeoutMs(15_000)
        val resolving = ResolvingDataSource.Factory(http) { dataSpec ->
            dataSpec.buildUpon()
                .setHttpRequestHeaders(MediaCatalog.headers(dataSpec.uri))
                .build()
        }
        val dataSources = DefaultDataSource.Factory(this, resolving)
        player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSources))
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
        player.addListener(object : Player.Listener {
            override fun onEvents(player: Player, events: Player.Events) {
                publish()
                attachEqualizerIfNeeded()
                if (player.isPlaying) startPositionUpdates() else positionJob?.cancel()
            }
        })
        session = MediaSession.Builder(this, player).build()
        equalizerSettingsStore = EqualizerSettingsStore(this)
        EqualizerBridge.update(equalizerSettingsStore.load())
        scope.launch {
            EqualizerBridge.settings.collect { settings ->
                runCatching { equalizerSettingsStore.save(settings) }
                applyEqualizer(settings)
            }
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession = session

    private fun publish() {
        val current = player.currentMediaItem?.mediaId?.let(MediaCatalog::track)
        PlaybackStateBus.publish(
            PlaybackSnapshot(
                current = current,
                positionMs = player.currentPosition.coerceAtLeast(0),
                durationMs = player.duration.takeIf { it != C.TIME_UNSET }?.coerceAtLeast(0) ?: current?.durationMs ?: 0,
                isPlaying = player.isPlaying,
                isLoading = player.playbackState == Player.STATE_BUFFERING,
                shuffleEnabled = player.shuffleModeEnabled,
                repeatMode = player.repeatMode,
            ),
        )
    }

    private fun startPositionUpdates() {
        if (positionJob?.isActive == true) return
        positionJob = scope.launch {
            while (isActive && player.isPlaying) {
                publish()
                delay(1_000)
            }
        }
    }

    private fun attachEqualizerIfNeeded() {
        val audioSessionId = player.audioSessionId
        if (audioSessionId == C.AUDIO_SESSION_ID_UNSET || audioSessionId == equalizerSessionId) return
        equalizer?.release()
        equalizer = runCatching { Equalizer(0, audioSessionId) }.getOrNull()
        equalizerSessionId = audioSessionId
        applyEqualizer(EqualizerBridge.settings.value)
    }

    private fun applyEqualizer(settings: EqualizerSettings) {
        val effect = equalizer ?: return
        runCatching {
            effect.enabled = settings.enabled
            val min = effect.bandLevelRange[0].toDouble() / 100
            val max = effect.bandLevelRange[1].toDouble() / 100
            val gains = settings.gains ?: settings.preset.gains(effect.numberOfBands.toInt(), min, max)
            for (band in 0 until effect.numberOfBands) {
                val gain = gains.getOrElse(band) { 0.0 }.coerceIn(min, max)
                effect.setBandLevel(band.toShort(), (gain * 100).toInt().toShort())
            }
        }
    }

    override fun onDestroy() {
        positionJob?.cancel()
        scope.cancel()
        equalizer?.release()
        equalizer = null
        session.release()
        player.release()
        PlaybackStateBus.publish(PlaybackSnapshot())
        super.onDestroy()
    }
}
