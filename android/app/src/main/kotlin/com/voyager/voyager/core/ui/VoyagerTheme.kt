package com.voyager.voyager.core.ui

import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp

object VoyagerColors {
    val Ground = Color(0xFF02040F)
    val Surface = Color(0xFF0D1024)
    val SurfaceRaised = Color(0xFF161A33)
    val Accent = Color(0xFF812DF8)
    val AccentLight = Color(0xFFBCBBFC)
    val AccentMid = Color(0xFF8B5CF6)
    val TextPrimary = Color(0xFFEDEBFB)
    val TextSecondary = Color(0xFF9A9AB8)
    val Border = Color(0xFF242847)
    val Success = Color(0xFF3DD68C)
    val Warning = Color(0xFFFFB020)
    val Error = Color(0xFFF2555A)
}

private val AutomotiveColorScheme = darkColorScheme(
    primary = VoyagerColors.Accent,
    onPrimary = VoyagerColors.TextPrimary,
    background = VoyagerColors.Ground,
    onBackground = VoyagerColors.TextPrimary,
    surface = VoyagerColors.SurfaceRaised,
    onSurface = VoyagerColors.TextPrimary,
    surfaceVariant = VoyagerColors.SurfaceRaised,
    onSurfaceVariant = VoyagerColors.TextSecondary,
    error = VoyagerColors.Error,
)

@Composable
fun VoyagerTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = AutomotiveColorScheme,
        typography = MaterialTheme.typography.copy(
            bodyLarge = MaterialTheme.typography.bodyLarge.copy(fontSize = 20.sp),
            bodyMedium = MaterialTheme.typography.bodyMedium.copy(fontSize = 16.sp),
            headlineMedium = MaterialTheme.typography.headlineMedium.copy(fontSize = 28.sp),
        ),
    ) {
        CompositionLocalProvider(LocalContentColor provides VoyagerColors.TextPrimary) {
            content()
        }
    }
}
