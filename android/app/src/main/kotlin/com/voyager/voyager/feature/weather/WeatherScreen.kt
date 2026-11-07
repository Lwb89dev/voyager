package com.voyager.voyager.feature.weather

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.Air
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.CloudOff
import androidx.compose.material.icons.rounded.LocationOn
import androidx.compose.material.icons.rounded.Thunderstorm
import androidx.compose.material.icons.rounded.WarningAmber
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.VoyagerColors
import kotlin.math.roundToInt

@Composable
fun WeatherScreen(plugin: WeatherPlugin) {
    val state by plugin.state.collectAsStateWithLifecycle()
    BoxWithConstraints(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).padding(24.dp)) {
        val compact = maxHeight < 340.dp
        val data = state.data
        when {
            data != null -> Conditions(state = state, compact = compact, modifier = Modifier.align(Alignment.Center))
            state.loading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            else -> Unavailable(state = state, modifier = Modifier.align(Alignment.Center))
        }
    }
}

@Composable
private fun Conditions(state: WeatherUiState, compact: Boolean, modifier: Modifier = Modifier) {
    val data = state.data ?: return
    if (compact) {
        Row(modifier = modifier, horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            WeatherIcon(data.code, compact = true)
            Temperature(data.temperatureCelsius, compact = true, modifier = Modifier.padding(start = 16.dp))
            Column(modifier = Modifier.padding(start = 20.dp)) {
                PlaceName(state)
                Text(
                    text = stringResource(descriptionResource(data.code)),
                    modifier = Modifier.padding(top = if (state.placeName == null) 0.dp else 4.dp),
                    color = VoyagerColors.TextPrimary,
                    fontSize = 20.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Wind(data, modifier = Modifier.padding(top = 4.dp), compact = true)
                AdditionalConditions(state, data, compact = true)
            }
        }
    } else {
        Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
            PlaceName(state)
            WeatherIcon(data.code, compact = false, modifier = Modifier.padding(top = if (state.placeName == null) 0.dp else 10.dp))
            Temperature(data.temperatureCelsius, compact = false, modifier = Modifier.padding(top = 8.dp))
            Text(
                text = stringResource(descriptionResource(data.code)),
                modifier = Modifier.padding(top = 8.dp),
                color = VoyagerColors.TextPrimary,
                fontSize = 28.sp,
                textAlign = TextAlign.Center,
            )
            Wind(data, modifier = Modifier.padding(top = 6.dp), compact = false)
            AdditionalConditions(state, data, compact = false)
        }
    }
}

@Composable
private fun PlaceName(state: WeatherUiState) {
    state.placeName?.let { place ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.LocationOn, contentDescription = null, tint = VoyagerColors.TextSecondary, modifier = Modifier.size(22.dp))
            Text(place, modifier = Modifier.padding(start = 6.dp), color = VoyagerColors.TextSecondary, fontSize = 20.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun AdditionalConditions(state: WeatherUiState, data: WeatherData, compact: Boolean) {
    if (state.stale) {
        Text(
            text = stringResource(R.string.voyager_weather_cached),
            modifier = Modifier.padding(top = 4.dp),
            color = VoyagerColors.TextSecondary,
            fontSize = 16.sp,
        )
    }
    val hazard = WeatherAlerts.assess(data)
    if (hazard != DrivingHazard.NONE) HazardBanner(data, hazard, compact)
}

@Composable
private fun WeatherIcon(code: Int, compact: Boolean, modifier: Modifier = Modifier) {
    Icon(
        imageVector = iconResource(code),
        contentDescription = null,
        tint = VoyagerColors.TextPrimary,
        modifier = modifier.size(if (compact) 56.dp else 96.dp),
    )
}

@Composable
private fun Temperature(celsius: Double, compact: Boolean, modifier: Modifier = Modifier) {
    Text(
        text = stringResource(R.string.voyager_weather_temperature, celsius.roundToInt()),
        modifier = modifier,
        color = VoyagerColors.TextPrimary,
        fontSize = if (compact) 52.sp else 84.sp,
        lineHeight = if (compact) 52.sp else 84.sp,
        fontWeight = FontWeight.Light,
    )
}

@Composable
private fun Wind(data: WeatherData, modifier: Modifier = Modifier, compact: Boolean) {
    Text(
        text = stringResource(R.string.voyager_weather_wind, data.windKmh.roundToInt()),
        modifier = modifier,
        color = VoyagerColors.TextSecondary,
        fontSize = if (compact) 16.sp else 20.sp,
    )
}

@Composable
private fun HazardBanner(data: WeatherData, hazard: DrivingHazard, compact: Boolean) {
    val color = if (hazard == DrivingHazard.SEVERE) VoyagerColors.Error else VoyagerColors.Warning
    val message = when {
        hazard == DrivingHazard.SEVERE && WeatherAlerts.isWindOnlySevere(data) -> R.string.voyager_weather_wind_warning
        hazard == DrivingHazard.SEVERE -> R.string.voyager_weather_severe_warning
        else -> R.string.voyager_weather_caution_warning
    }
    Row(
        modifier = Modifier
            .padding(top = if (compact) 6.dp else 24.dp)
            .background(color.copy(alpha = 0.14f), RoundedCornerShape(14.dp))
            .border(1.dp, color.copy(alpha = 0.5f), RoundedCornerShape(14.dp))
            .padding(horizontal = 18.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.WarningAmber, contentDescription = null, tint = color, modifier = Modifier.size(28.dp))
        Text(stringResource(message), color = color, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun Unavailable(state: WeatherUiState, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Rounded.CloudOff, contentDescription = null, tint = VoyagerColors.TextSecondary, modifier = Modifier.size(64.dp))
        Text(
            text = stringResource(if (state.waitingForLocation) R.string.voyager_weather_waiting_location else R.string.voyager_weather_unavailable),
            modifier = Modifier.padding(top = 16.dp),
            color = VoyagerColors.TextSecondary,
            fontSize = 20.sp,
        )
    }
}

private fun iconResource(code: Int): ImageVector = when {
    code == 0 -> Icons.Rounded.WbSunny
    code <= 3 -> Icons.Rounded.Cloud
    code <= 48 -> Icons.Rounded.Cloud
    code <= 65 -> Icons.Rounded.WaterDrop
    code <= 77 -> Icons.Rounded.AcUnit
    code <= 82 -> Icons.Rounded.WaterDrop
    code == 95 || code >= 96 -> Icons.Rounded.Thunderstorm
    else -> Icons.Rounded.Air
}

private fun descriptionResource(code: Int): Int = when {
    code == 0 -> R.string.voyager_weather_clear
    code <= 2 -> R.string.voyager_weather_partly_cloudy
    code == 3 -> R.string.voyager_weather_cloudy
    code <= 48 -> R.string.voyager_weather_fog
    code <= 55 -> R.string.voyager_weather_light_rain
    code <= 65 -> R.string.voyager_weather_rain
    code <= 77 -> R.string.voyager_weather_snow
    code <= 82 -> R.string.voyager_weather_showers
    else -> R.string.voyager_weather_thunderstorm
}
