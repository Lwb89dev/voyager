package com.voyager.voyager.feature.voice

import app.roadstr.core.speech.SpeechOutcome
import app.roadstr.feature.speech.NativeSpeechGateway
import app.roadstr.feature.speech.NativeSpeechModelStatus
import app.roadstr.feature.speech.NativeSpeechPhase
import app.roadstr.feature.speech.NativeSpeechSnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class VoicePluginTest {
    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun recognizedCommandUsesRealDispatcherAndStopsGuidanceBeforeListening() = runTest {
        val gateway = FakeSpeechGateway()
        var next = 0
        var stopped = 0
        val plugin = plugin(
            gateway = gateway,
            dispatcher = dispatcher { next += 1 },
            stopGuidance = { stopped += 1 },
        )
        plugin.startListening()
        assertEquals(1, stopped)
        assertTrue(plugin.state.value.listening)

        gateway.succeed("next track")
        runCurrent()
        assertEquals(1, next)
        assertEquals(VoiceStatus.REQUESTED, plugin.state.value.status)
        assertEquals("next track", plugin.state.value.transcript)
        plugin.close()
    }

    @Test
    fun unavailableOfflineModelDoesNotRequestMicrophone() = runTest {
        val gateway = FakeSpeechGateway(available = false)
        var permissionRequests = 0
        val plugin = plugin(
            gateway = gateway,
            hasPermission = false,
            requestPermission = { permissionRequests += 1 },
        )
        plugin.startListening()
        assertEquals(0, permissionRequests)
        assertEquals(VoiceStatus.UNAVAILABLE, plugin.state.value.status)
        assertFalse(gateway.listening)
        plugin.close()
    }

    @Test
    fun microphoneIsRequestedOnlyAfterExplicitStart() = runTest {
        val gateway = FakeSpeechGateway()
        var permissionRequests = 0
        var providerCalls = 0
        val plugin = plugin(
            gateway = gateway,
            hasPermission = false,
            requestPermission = { permissionRequests += 1 },
            providerCalls = { providerCalls += 1 },
        )
        assertEquals(0, providerCalls)
        assertEquals(0, permissionRequests)

        plugin.startListening()
        assertEquals(1, providerCalls)
        assertEquals(1, permissionRequests)
        assertFalse(gateway.listening)

        plugin.onMicrophonePermission(false)
        assertEquals(VoiceStatus.PERMISSION_DENIED, plugin.state.value.status)
        plugin.close()
    }

    private fun plugin(
        gateway: FakeSpeechGateway,
        dispatcher: VoiceCommandDispatcher = dispatcher {},
        hasPermission: Boolean = true,
        requestPermission: () -> Unit = {},
        stopGuidance: () -> Unit = {},
        providerCalls: () -> Unit = {},
    ) = VoicePlugin(
        speechProvider = {
            providerCalls()
            gateway
        },
        dispatcher = dispatcher,
        languageTag = { "en-US" },
        hasMicrophonePermission = { hasPermission },
        requestMicrophonePermission = requestPermission,
        stopGuidance = stopGuidance,
    )

    private fun dispatcher(next: () -> Unit) = VoiceCommandDispatcher(
        playMusic = {},
        playPause = {},
        nextTrack = next,
        previousTrack = {},
        showNavigation = {},
        showWeather = {},
    )

    private class FakeSpeechGateway(
        private val available: Boolean = true,
    ) : NativeSpeechGateway {
        private val mutableState = MutableStateFlow(
            NativeSpeechSnapshot(model = NativeSpeechModelStatus.Ready),
        )
        override val state: StateFlow<NativeSpeechSnapshot> = mutableState
        private var outcome: ((SpeechOutcome) -> Unit)? = null
        var listening: Boolean = false

        override fun canRecognize(languageTag: String): Boolean = available
        override fun downloadModel() = Unit
        override fun cancelDownload() = Unit
        override fun deleteModel() = Unit
        override fun listen(languageTag: String, onOutcome: (SpeechOutcome) -> Unit) {
            outcome = onOutcome
            listening = true
            mutableState.value = mutableState.value.copy(phase = NativeSpeechPhase.Listening)
        }

        override fun finishListening() = Unit
        override fun cancelListening() {
            listening = false
            mutableState.value = mutableState.value.copy(phase = NativeSpeechPhase.Idle)
        }

        override fun trimMemory() = Unit
        override fun close() = Unit

        fun succeed(text: String) {
            listening = false
            mutableState.value = mutableState.value.copy(phase = NativeSpeechPhase.Idle)
            outcome?.invoke(SpeechOutcome.Text(text, decodeMillis = 1))
        }
    }
}
