package com.voyager.voyager.feature.dashboard

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.DrivingState
import com.voyager.voyager.core.plugin.PluginLifecycleState
import com.voyager.voyager.core.plugin.PluginService
import com.voyager.voyager.core.plugin.VoyagerPlugin
import com.voyager.voyager.core.ui.AutomotiveButton
import com.voyager.voyager.core.ui.VoyagerColors
import kotlinx.coroutines.launch

@Composable
fun AutomotiveDashboard(
    plugins: PluginService,
    navigationContent: @Composable () -> Unit,
    onOpenSettings: (() -> Unit)?,
    chromeVisible: Boolean,
    collapsed: Boolean,
    onToggleCollapsed: () -> Unit,
) {
    val activeId by plugins.activeId.collectAsStateWithLifecycle()
    val drivingState by plugins.drivingState.collectAsStateWithLifecycle()
    val states = plugins.registered.associate { plugin ->
        plugin.manifest.id to plugin.lifecycle.collectAsStateWithLifecycle().value
    }
    val availability = plugins.registered.associate { plugin ->
        plugin.manifest.id to plugin.available.collectAsStateWithLifecycle().value
    }
    val overlayRequests = plugins.registered.associate { plugin ->
        plugin.manifest.id to plugin.wantsOverlay.collectAsStateWithLifecycle().value
    }
    val visible = plugins.visible.filter { availability[it.manifest.id] == true }
    val active = plugins.active
    val overlay = plugins.registered
        .filter {
            availability[it.manifest.id] == true &&
                it.manifest.providesOverlay &&
                overlayRequests[it.manifest.id] == true &&
                it.manifest.id != activeId
        }
        .maxByOrNull { it.manifest.overlayPriority }
    val density = LocalDensity.current
    val systemBottom = with(density) { WindowInsets.navigationBars.getBottom(this).toDp() }
    val reserved = if (chromeVisible) (if (collapsed) 52.dp else 84.dp) + systemBottom else 0.dp

    Box(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground)) {
        Box(modifier = Modifier.fillMaxSize().padding(bottom = reserved)) {
            navigationContent()
        }

        if (chromeVisible && active != null && active.manifest.id != NavigationPlugin.ID) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(VoyagerColors.Ground)
                    .padding(bottom = if (active.manifest.respectsChromeInset) reserved else 0.dp),
            ) {
                when (val state = states[active.manifest.id]) {
                    PluginLifecycleState.Ready -> active.FullscreenContent()
                    is PluginLifecycleState.Error -> PluginError(active, state.reason)
                    else -> PluginLoading()
                }
            }
        }

        if (chromeVisible) {
            overlay?.let { plugin ->
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(start = 16.dp, end = 16.dp, bottom = reserved + 16.dp),
                ) {
                    plugin.OverlayContent()
                }
            }

            AutomotiveButtonBar(
                plugins = visible.filter { it.manifest.canBeFullscreen },
                activeId = activeId,
                drivingState = drivingState,
                collapsed = collapsed,
                onToggleCollapsed = onToggleCollapsed,
                onSelect = plugins::activate,
                onOpenSettings = onOpenSettings,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

@Composable
private fun AutomotiveButtonBar(
    plugins: List<VoyagerPlugin>,
    activeId: String?,
    drivingState: DrivingState,
    collapsed: Boolean,
    onToggleCollapsed: () -> Unit,
    onSelect: (String) -> Unit,
    onOpenSettings: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier = modifier.navigationBarsPadding().padding(bottom = 8.dp)) {
        if (collapsed) {
            val active = plugins.firstOrNull { it.manifest.id == activeId }
            ChromeSurface(
                modifier = Modifier
                    .width(116.dp)
                    .height(44.dp)
                    .clickable(onClick = onToggleCollapsed)
                    .semantics {
                        contentDescription = "Show controls"
                        role = Role.Button
                    },
            ) {
                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = active?.manifest?.icon ?: Icons.Rounded.ExpandLess,
                        contentDescription = null,
                        tint = VoyagerColors.AccentLight,
                        modifier = Modifier.size(22.dp),
                    )
                    Icon(
                        imageVector = Icons.Rounded.ExpandLess,
                        contentDescription = null,
                        tint = VoyagerColors.TextSecondary,
                        modifier = Modifier.padding(start = 8.dp).size(22.dp),
                    )
                }
            }
        } else {
            ChromeSurface(
                modifier = Modifier
                    .widthIn(max = (maxWidth - 32.dp).coerceAtLeast(0.dp))
                    .animateContentSize(tween(180)),
            ) {
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()).height(76.dp).padding(start = 10.dp, end = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    plugins.forEach { plugin ->
                        ChromeButton(
                            plugin = plugin,
                            selected = plugin.manifest.id == activeId,
                            enabled = plugin.manifest.drivingPolicy == com.voyager.voyager.core.plugin.DrivingPolicy.ALLOWED ||
                                drivingState == DrivingState.PARKED,
                            onClick = { onSelect(plugin.manifest.id) },
                        )
                    }
                    if (onOpenSettings != null) {
                        ChromeIconButton(
                            label = stringResource(R.string.voyager_settings),
                            icon = Icons.Rounded.Settings,
                            onClick = onOpenSettings,
                        )
                    }
                    ChromeIconButton(
                        label = stringResource(R.string.voyager_hide),
                        icon = Icons.Rounded.ExpandMore,
                        onClick = onToggleCollapsed,
                    )
                }
            }
        }
    }
}

@Composable
private fun ChromeSurface(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(22.dp),
        color = VoyagerColors.Surface.copy(alpha = 0.96f),
        border = androidx.compose.foundation.BorderStroke(1.dp, VoyagerColors.Border),
        shadowElevation = 8.dp,
        content = content,
    )
}

@Composable
private fun ChromeButton(plugin: VoyagerPlugin, selected: Boolean, enabled: Boolean, onClick: () -> Unit) {
    ChromeIconButton(
        label = stringResource(plugin.manifest.label),
        icon = plugin.manifest.icon,
        selected = selected,
        enabled = enabled,
        onClick = onClick,
    )
}

@Composable
private fun ChromeIconButton(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    selected: Boolean = false,
    enabled: Boolean = true,
) {
    Box(
        modifier = Modifier
            .size(60.dp)
            .background(if (selected) VoyagerColors.Accent.copy(alpha = 0.2f) else androidx.compose.ui.graphics.Color.Transparent, RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics {
                contentDescription = label
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = when {
                !enabled -> VoyagerColors.TextSecondary.copy(alpha = 0.4f)
                selected -> VoyagerColors.AccentLight
                else -> VoyagerColors.TextPrimary
            },
            modifier = Modifier.size(28.dp),
        )
    }
}

@Composable
private fun PluginLoading() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator()
            Text(
                text = stringResource(R.string.voyager_loading),
                modifier = Modifier.padding(top = 20.dp),
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
}

@Composable
private fun PluginError(plugin: VoyagerPlugin, reason: String) {
    val scope = rememberCoroutineScope()
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = stringResource(R.string.voyager_plugin_unavailable, stringResource(plugin.manifest.label)),
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            text = reason,
            modifier = Modifier.padding(top = 16.dp),
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
        AutomotiveButton(
            label = stringResource(R.string.voyager_retry),
            icon = Icons.Rounded.Settings,
            onClick = { scope.launch { plugin.initializeSafely() } },
            modifier = Modifier.padding(top = 24.dp),
        )
    }
}
