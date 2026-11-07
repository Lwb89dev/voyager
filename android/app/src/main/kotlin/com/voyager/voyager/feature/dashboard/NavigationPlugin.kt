package com.voyager.voyager.feature.dashboard

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Navigation
import androidx.compose.runtime.Composable
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin

class NavigationPlugin(
    private val content: @Composable () -> Unit,
) : VoyagerPlugin() {
    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_navigation,
        icon = Icons.Rounded.Navigation,
        order = 0,
        respectsChromeInset = false,
    )

    override suspend fun initialize() = Unit

    @Composable
    override fun FullscreenContent() = content()

    companion object {
        const val ID = "navigation"
    }
}
