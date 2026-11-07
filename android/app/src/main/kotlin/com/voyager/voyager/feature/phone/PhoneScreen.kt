package com.voyager.voyager.feature.phone

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.VoyagerColors

@Composable
fun PhoneScreen(plugin: PhonePlugin, compact: Boolean = false) {
    val call by plugin.state.collectAsStateWithLifecycle()
    val current = call
    if (current == null) {
        Box(modifier = if (compact) Modifier else Modifier.fillMaxSize().background(VoyagerColors.Ground), contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(R.string.voyager_no_active_call),
                modifier = if (compact) Modifier.padding(32.dp) else Modifier,
                color = VoyagerColors.TextSecondary,
                fontSize = 20.sp,
            )
        }
        return
    }
    Column(
        modifier = Modifier
            .then(if (compact) Modifier else Modifier.fillMaxSize())
            .background(if (compact) VoyagerColors.Surface else VoyagerColors.Ground, RoundedCornerShape(if (compact) 20.dp else 0.dp))
            .then(if (compact) Modifier.border(1.dp, VoyagerColors.Accent, RoundedCornerShape(20.dp)) else Modifier)
            .padding(if (compact) 16.dp else 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = if (compact) Arrangement.Top else Arrangement.Center,
    ) {
        Text(
            text = current.number.ifBlank { stringResource(R.string.voyager_unknown_caller) },
            color = VoyagerColors.TextPrimary,
            fontSize = if (compact) 26.sp else 44.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = if (compact) 12.dp else 24.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            CallAction(
                icon = Icons.Rounded.CallEnd,
                color = VoyagerColors.Error,
                label = stringResource(R.string.voyager_reject_call),
                onClick = { plugin.reject() },
            )
            if (current.ringing) {
                CallAction(
                    icon = Icons.Rounded.Call,
                    color = VoyagerColors.Success,
                    label = stringResource(R.string.voyager_answer_call),
                    onClick = { plugin.answer() },
                )
            }
        }
    }
}

@Composable
private fun CallAction(icon: ImageVector, color: Color, label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(96.dp)
            .clip(CircleShape)
            .background(color)
            .clickable(onClick = onClick)
            .semantics {
                contentDescription = label
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(44.dp))
    }
}
