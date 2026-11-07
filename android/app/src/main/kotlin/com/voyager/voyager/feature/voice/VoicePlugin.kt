package com.voyager.voyager.feature.voice

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.runtime.Composable
import app.roadstr.core.speech.SpeechOutcome
import app.roadstr.feature.speech.NativeSpeechGateway
import app.roadstr.feature.speech.NativeSpeechPhase
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.PhysicalButton
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

enum class VoiceStatus {
    IDLE,
    LISTENING,
    REQUESTED,
    LOW_CONFIDENCE,
    UNKNOWN,
    UNSUPPORTED,
    NOTHING_HEARD,
    PERMISSION_DENIED,
    UNAVAILABLE,
}

data class VoiceUiState(
    val status: VoiceStatus = VoiceStatus.IDLE,
    val transcript: String? = null,
) {
    val listening: Boolean get() = status == VoiceStatus.LISTENING
}

class VoicePlugin(
    private val speechProvider: () -> NativeSpeechGateway,
    private val dispatcher: VoiceCommandDispatcher,
    private val languageTag: () -> String,
    private val hasMicrophonePermission: () -> Boolean,
    private val requestMicrophonePermission: () -> Unit,
    private val stopGuidance: () -> Unit,
) : VoyagerPlugin() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var speech: NativeSpeechGateway? = null
    private var clearJob: Job? = null
    private val _state = MutableStateFlow(VoiceUiState())
    val state: StateFlow<VoiceUiState> = _state
    private val _wantsOverlay = MutableStateFlow(false)
    override val wantsOverlay: StateFlow<Boolean> = _wantsOverlay

    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_voice,
        icon = Icons.Rounded.Mic,
        order = 4,
        canBeFullscreen = false,
        providesOverlay = true,
        overlayPriority = 2,
    )

    override suspend fun initialize() = Unit

    override fun onTrigger() = startListening()

    fun startListening() {
        clearJob?.cancel()
        if (_state.value.listening) {
            speech?.finishListening()
            return
        }
        val gateway = speech ?: speechProvider().also { created ->
            speech = created
            scope.launch {
                created.state.collect { snapshot ->
                    if (snapshot.phase == NativeSpeechPhase.Idle && _state.value.listening) {
                        _state.value = _state.value.copy(status = VoiceStatus.IDLE)
                    } else if (snapshot.phase != NativeSpeechPhase.Idle) {
                        _wantsOverlay.value = true
                        _state.value = _state.value.copy(status = VoiceStatus.LISTENING)
                    }
                }
            }
        }
        val language = languageTag()
        if (!gateway.canRecognize(language)) {
            present(VoiceStatus.UNAVAILABLE)
            return
        }
        if (!hasMicrophonePermission()) {
            requestMicrophonePermission()
            return
        }
        beginListening(gateway, language)
    }

    fun onMicrophonePermission(granted: Boolean) {
        if (granted) {
            startListening()
        } else {
            present(VoiceStatus.PERMISSION_DENIED)
        }
    }

    private fun beginListening(gateway: NativeSpeechGateway, language: String) {
        runCatching { stopGuidance() }
        _wantsOverlay.value = true
        _state.value = VoiceUiState(status = VoiceStatus.LISTENING)
        gateway.listen(language, ::onOutcome)
    }

    private fun onOutcome(outcome: SpeechOutcome) {
        when (outcome) {
            is SpeechOutcome.Text -> {
                val language = if (languageTag().startsWith("it", ignoreCase = true)) {
                    VoiceLanguage.ITALIAN
                } else {
                    VoiceLanguage.ENGLISH
                }
                val command = VoiceCommandParser(language).parse(outcome.text)
                val status = when (dispatcher.dispatch(command)) {
                    VoiceDispatchResult.REQUESTED -> VoiceStatus.REQUESTED
                    VoiceDispatchResult.LOW_CONFIDENCE -> VoiceStatus.LOW_CONFIDENCE
                    VoiceDispatchResult.UNKNOWN -> VoiceStatus.UNKNOWN
                    VoiceDispatchResult.UNSUPPORTED -> VoiceStatus.UNSUPPORTED
                }
                present(status, outcome.text)
            }
            SpeechOutcome.NothingHeard -> present(VoiceStatus.NOTHING_HEARD)
            SpeechOutcome.Cancelled -> hide()
            is SpeechOutcome.Unavailable -> present(VoiceStatus.UNAVAILABLE)
        }
    }

    private fun present(status: VoiceStatus, transcript: String? = null) {
        _state.value = VoiceUiState(status = status, transcript = transcript)
        _wantsOverlay.value = true
        clearJob?.cancel()
        clearJob = scope.launch {
            delay(4_000)
            hide()
        }
    }

    private fun hide() {
        clearJob?.cancel()
        _wantsOverlay.value = false
        _state.value = VoiceUiState()
    }

    override fun onPhysicalButtonPress(button: PhysicalButton): Boolean {
        if (button != PhysicalButton.VOICE) return false
        startListening()
        return true
    }

    @Composable
    override fun FullscreenContent() = VoiceStatusCard(this)

    @Composable
    override fun OverlayContent() = VoiceStatusCard(this)

    override fun close() {
        speech?.cancelListening()
        scope.cancel()
    }

    companion object {
        const val ID = "voice"
    }
}
