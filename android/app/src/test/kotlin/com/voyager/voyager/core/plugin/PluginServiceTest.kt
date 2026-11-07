package com.voyager.voyager.core.plugin

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Map
import androidx.compose.runtime.Composable
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PluginServiceTest {
    @Test
    fun initializationIsConcurrentAndContainsFailure() = runTest {
        val service = PluginService()
        val slow = FakePlugin("slow", delayMillis = 150)
        val broken = FakePlugin("broken", failure = IllegalStateException("server"))
        val fast = FakePlugin("fast", delayMillis = 10)
        service.register(slow)
        service.register(broken)
        service.register(fast)

        service.initializeAll()

        assertTrue(slow.lifecycle.value is PluginLifecycleState.Ready)
        assertTrue(fast.lifecycle.value is PluginLifecycleState.Ready)
        assertTrue(broken.lifecycle.value is PluginLifecycleState.Error)
        assertEquals("slow", service.activeId.value)
        assertTrue(fast.initialized)
    }

    @Test
    fun overlayGetsHardwareInputBeforeActivePlugin() = runTest {
        val service = PluginService()
        val map = FakePlugin("map")
        val call = FakePlugin("call", overlay = true, priority = 3).apply {
            wantsOverlay.value = true
        }
        service.register(map)
        service.register(call)
        service.initializeAll()

        assertTrue(service.dispatchButton(PhysicalButton.MEDIA_NEXT))
        assertEquals(1, call.buttonCount)
        assertEquals(0, map.buttonCount)
    }

    @Test
    fun globalAssistantReceivesKeyWithoutBeingActiveOrAnOverlay() = runTest {
        val service = PluginService()
        val map = FakePlugin("map")
        val voice = FakePlugin("voice", fullscreen = false, handledButton = PhysicalButton.VOICE)
        service.register(map)
        service.register(voice)
        service.initializeAll()

        assertTrue(service.dispatchButton(PhysicalButton.VOICE))
        assertEquals(1, map.buttonCount)
        assertEquals(1, voice.buttonCount)
    }

    @Test
    fun unavailablePluginDoesNotReceiveGlobalKeys() = runTest {
        val service = PluginService()
        val map = FakePlugin("map")
        val hidden = FakePlugin("hidden", handledButton = PhysicalButton.VOICE).apply {
            available.value = false
        }
        service.register(map)
        service.register(hidden)
        service.initializeAll()

        assertFalse(service.dispatchButton(PhysicalButton.VOICE))
        assertEquals(0, hidden.buttonCount)
    }

    @Test
    fun parkedOnlyPluginIsBlockedAndClosedWhenDrivingStateChanges() = runTest {
        val service = PluginService()
        val navigation = FakePlugin("navigation")
        val podcast = FakePlugin("podcast", drivingPolicy = DrivingPolicy.PARKED_ONLY)
        service.register(navigation)
        service.register(podcast)
        service.initializeAll()

        service.activate("podcast")
        assertEquals("navigation", service.activeId.value)
        service.setDrivingState(DrivingState.PARKED)
        service.activate("podcast")
        assertEquals("podcast", service.activeId.value)
        service.setDrivingState(DrivingState.MOVING)
        assertEquals("navigation", service.activeId.value)
    }

    @Test
    fun unavailableOrNonFullscreenPluginCannotBeActivated() = runTest {
        val service = PluginService()
        val map = FakePlugin("map")
        val hidden = FakePlugin("hidden").apply { available.value = false }
        service.register(map)
        service.register(hidden)
        service.activate("hidden")
        service.activate("missing")

        assertEquals("map", service.activeId.value)
        assertFalse(service.dispatchButton(PhysicalButton.MENU))
    }

    private class FakePlugin(
        id: String,
        private val delayMillis: Long = 0,
        private val failure: Throwable? = null,
        overlay: Boolean = false,
        priority: Int = 0,
        fullscreen: Boolean = true,
        private val handledButton: PhysicalButton? = null,
        drivingPolicy: DrivingPolicy = DrivingPolicy.ALLOWED,
    ) : VoyagerPlugin() {
        override val manifest = PluginManifest(
            id = id,
            label = 0,
            icon = Icons.Rounded.Map,
            order = 0,
            canBeFullscreen = fullscreen,
            providesOverlay = overlay,
            overlayPriority = priority,
            drivingPolicy = drivingPolicy,
        )
        override val available = MutableStateFlow(true)
        override val wantsOverlay = MutableStateFlow(false)
        var initialized = false
        var buttonCount = 0

        override suspend fun initialize() {
            if (delayMillis > 0) delay(delayMillis)
            failure?.let { throw it }
            initialized = true
        }

        @Composable
        override fun FullscreenContent() = Unit

        override fun onPhysicalButtonPress(button: PhysicalButton): Boolean {
            buttonCount += 1
            return wantsOverlay.value || button == handledButton
        }
    }
}
