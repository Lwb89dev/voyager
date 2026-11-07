package com.voyager.voyager.core.plugin

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.vector.ImageVector
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

enum class DrivingPolicy {
    ALLOWED,
    PARKED_ONLY,
}

data class PluginMetadata(
    val version: String = "1",
    val author: String = "Voyager",
)

data class PluginManifest(
    val id: String,
    @StringRes val label: Int,
    val icon: ImageVector,
    val order: Int,
    val canBeFullscreen: Boolean = true,
    val providesOverlay: Boolean = false,
    val overlayPriority: Int = 0,
    val respectsChromeInset: Boolean = true,
    val drivingPolicy: DrivingPolicy = DrivingPolicy.ALLOWED,
    val metadata: PluginMetadata = PluginMetadata(),
)

sealed interface PluginLifecycleState {
    data object NotInitialized : PluginLifecycleState
    data object Initializing : PluginLifecycleState
    data object Ready : PluginLifecycleState
    data class Error(val reason: String) : PluginLifecycleState
}

enum class PhysicalButton {
    VOLUME_UP,
    VOLUME_DOWN,
    MEDIA_NEXT,
    MEDIA_PREVIOUS,
    MEDIA_PLAY_PAUSE,
    VOICE,
    MENU,
}

abstract class VoyagerPlugin {
    abstract val manifest: PluginManifest

    private val _lifecycle = MutableStateFlow<PluginLifecycleState>(PluginLifecycleState.NotInitialized)
    val lifecycle: StateFlow<PluginLifecycleState> = _lifecycle

    open val available: StateFlow<Boolean> = MutableStateFlow(true)
    open val wantsOverlay: StateFlow<Boolean> = MutableStateFlow(false)

    internal suspend fun initializeSafely() {
        _lifecycle.value = PluginLifecycleState.Initializing
        try {
            initialize()
            _lifecycle.value = PluginLifecycleState.Ready
        } catch (error: Throwable) {
            if (error is kotlinx.coroutines.CancellationException) throw error
            _lifecycle.value = PluginLifecycleState.Error(
                "Initialization failed (${error::class.simpleName ?: "unknown error"})",
            )
        }
    }

    protected abstract suspend fun initialize()

    @Composable
    abstract fun FullscreenContent()

    @Composable
    open fun OverlayContent() = Unit

    open fun onPhysicalButtonPress(button: PhysicalButton): Boolean = false

    open fun onTrigger() = Unit

    open fun onVisibilityChanged(visible: Boolean) = Unit

    open fun close() = Unit
}
