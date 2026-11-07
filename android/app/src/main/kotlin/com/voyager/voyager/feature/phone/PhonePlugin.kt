package com.voyager.voyager.feature.phone

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Phone
import androidx.compose.runtime.Composable
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

object PhoneCapability {
    fun available(hasTelephony: Boolean, inCallServiceDeclared: Boolean): Boolean =
        hasTelephony && inCallServiceDeclared
}

class PhonePlugin(context: Context) : VoyagerPlugin() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _available = MutableStateFlow(
        PhoneCapability.available(
            hasTelephony = context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
            inCallServiceDeclared = runCatching {
                context.packageManager.getServiceInfo(
                    ComponentName(context, VoyagerInCallService::class.java),
                    0,
                )
                true
            }.getOrDefault(false),
        ),
    )
    override val available: StateFlow<Boolean> = _available
    private val _wantsOverlay = MutableStateFlow(false)
    override val wantsOverlay: StateFlow<Boolean> = _wantsOverlay
    val state: StateFlow<CallInfo?> = CallStateBus.state

    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_phone,
        icon = Icons.Rounded.Phone,
        order = 5,
        providesOverlay = true,
        overlayPriority = 3,
    )

    override suspend fun initialize() {
        scope.launch {
            state.collect { call -> _wantsOverlay.value = call != null }
        }
    }

    fun answer(): Boolean = CallStateBus.answer()
    fun reject(): Boolean = CallStateBus.reject()

    @Composable
    override fun FullscreenContent() = PhoneScreen(this)

    @Composable
    override fun OverlayContent() = PhoneScreen(this, compact = true)

    override fun close() = scope.cancel()

    companion object {
        const val ID = "phone"
    }
}
