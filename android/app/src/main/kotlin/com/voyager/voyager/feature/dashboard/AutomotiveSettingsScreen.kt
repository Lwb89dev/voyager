package com.voyager.voyager.feature.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.VoyagerColors

@Composable
fun AutomotiveSettingsScreen(
    state: AutomotiveUiState,
    remapVolumeKeys: Boolean,
    onKeepAwakeChange: (Boolean) -> Unit,
    onNightDimmingChange: (Boolean) -> Unit,
    onRemapVolumeChange: (Boolean) -> Unit,
    onClose: () -> Unit,
) {
    val context = LocalContext.current
    val version = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName
    }.getOrNull().orEmpty()
    Column(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).statusBarsPadding().navigationBarsPadding()) {
        Row(modifier = Modifier.fillMaxWidth().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.voyager_back), tint = VoyagerColors.TextPrimary)
            }
            Text(stringResource(R.string.voyager_settings), color = VoyagerColors.TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 16.dp, top = 8.dp, end = 16.dp, bottom = 32.dp)) {
            item { SettingsSection(stringResource(R.string.voyager_section_display)) }
            item {
                SettingSwitch(
                    title = stringResource(R.string.voyager_keep_screen_on),
                    subtitle = stringResource(R.string.voyager_keep_screen_on_why),
                    checked = state.keepAwake,
                    onCheckedChange = onKeepAwakeChange,
                )
            }
            item {
                SettingSwitch(
                    title = stringResource(R.string.voyager_night_dimming),
                    subtitle = stringResource(R.string.voyager_night_dimming_why),
                    checked = state.nightDimming,
                    onCheckedChange = onNightDimmingChange,
                )
            }
            item {
                SettingSwitch(
                    title = stringResource(R.string.voyager_wheel_controls),
                    subtitle = stringResource(R.string.voyager_wheel_controls_why),
                    checked = remapVolumeKeys,
                    onCheckedChange = onRemapVolumeChange,
                )
            }
            item { SettingsSection(stringResource(R.string.voyager_section_info), modifier = Modifier.padding(top = 20.dp)) }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_version), version) }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_navigation), "Roadstr · OSRM") }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_maps), "openstreetmap.org") }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_weather), "open-meteo.com") }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_speech), "Kokoro · eSpeak-NG") }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_licence), "GPL v3") }
            item { SettingsInfoRow(stringResource(R.string.voyager_info_source), "github.com/Lwb89dev/voyager") }
        }
    }
}

@Composable
private fun SettingsSection(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title,
        modifier = modifier.padding(start = 4.dp, top = 4.dp, bottom = 8.dp),
        color = VoyagerColors.AccentLight,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.2.sp,
    )
}

@Composable
private fun SettingSwitch(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    SettingsRow {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, modifier = Modifier.weight(1f), color = VoyagerColors.TextPrimary, fontSize = 14.sp)
                Switch(
                    checked = checked,
                    onCheckedChange = onCheckedChange,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = VoyagerColors.AccentLight,
                        checkedTrackColor = VoyagerColors.Accent,
                        uncheckedThumbColor = VoyagerColors.TextSecondary,
                        uncheckedTrackColor = VoyagerColors.SurfaceRaised,
                    ),
                )
            }
            Text(subtitle, color = VoyagerColors.TextSecondary, fontSize = 12.sp, lineHeight = 16.8.sp)
        }
    }
}

@Composable
private fun SettingsInfoRow(title: String, value: String) {
    SettingsRow {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, modifier = Modifier.weight(1f), color = VoyagerColors.TextPrimary, fontSize = 14.sp)
            Text(value, color = VoyagerColors.TextSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun SettingsRow(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .background(VoyagerColors.Surface, RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 13.dp),
    ) {
        content()
    }
}
