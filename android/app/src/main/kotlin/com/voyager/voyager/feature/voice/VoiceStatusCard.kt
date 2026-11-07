package com.voyager.voyager.feature.voice

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.VoyagerColors

@Composable
fun VoiceStatusCard(plugin: VoicePlugin) {
    val state by plugin.state.collectAsStateWithLifecycle()
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = VoyagerColors.Surface.copy(alpha = 0.96f),
        border = androidx.compose.foundation.BorderStroke(1.dp, VoyagerColors.Accent),
        shadowElevation = 8.dp,
    ) {
        Row(modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            PulsingMic(active = state.listening)
            Text(
                text = state.transcript ?: stringResource(statusResource(state.status)),
                modifier = Modifier.padding(start = 14.dp),
                color = VoyagerColors.TextPrimary,
                fontSize = 20.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun PulsingMic(active: Boolean) {
    val transition = rememberInfiniteTransition(label = "microphone")
    val pulse by transition.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(animation = tween(900), repeatMode = RepeatMode.Reverse),
        label = "microphone alpha",
    )
    Box(
        modifier = Modifier.size(44.dp).background(VoyagerColors.Accent.copy(alpha = if (active) pulse else 0.25f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.Mic, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(26.dp))
    }
}

private fun statusResource(status: VoiceStatus): Int = when (status) {
    VoiceStatus.IDLE -> R.string.voyager_voice_ready
    VoiceStatus.LISTENING -> R.string.voyager_voice_listening
    VoiceStatus.REQUESTED -> R.string.voyager_voice_requested
    VoiceStatus.LOW_CONFIDENCE,
    VoiceStatus.UNKNOWN,
    -> R.string.voyager_voice_not_understood
    VoiceStatus.UNSUPPORTED -> R.string.voyager_voice_unsupported
    VoiceStatus.NOTHING_HEARD -> R.string.voyager_voice_nothing_heard
    VoiceStatus.PERMISSION_DENIED -> R.string.voyager_voice_permission_denied
    VoiceStatus.UNAVAILABLE -> R.string.voyager_voice_unavailable
}
