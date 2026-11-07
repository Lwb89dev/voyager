package com.voyager.voyager.legacy.migration

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.AutomotiveButton

enum class LegacyMigrationUiStage { Checking, Failed, Report, Ready }

data class LegacyMigrationUiState(
    val stage: LegacyMigrationUiStage = LegacyMigrationUiStage.Checking,
    val unsupportedData: Set<String> = emptySet(),
)

@Composable
fun LegacyMigrationScreen(
    state: LegacyMigrationUiState,
    onRetry: () -> Unit,
    onSkip: () -> Unit,
    onContinue: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        when (state.stage) {
            LegacyMigrationUiStage.Checking -> {
                CircularProgressIndicator()
                Text(
                    text = stringResource(R.string.voyager_migration_checking),
                    modifier = Modifier.padding(top = 24.dp),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                )
            }
            LegacyMigrationUiStage.Failed -> {
                Text(
                    text = stringResource(R.string.voyager_migration_failed),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                )
                AutomotiveButton(
                    label = stringResource(R.string.voyager_migration_retry),
                    icon = Icons.Rounded.PlayArrow,
                    onClick = onRetry,
                    modifier = Modifier.padding(top = 24.dp),
                )
                AutomotiveButton(
                    label = stringResource(R.string.voyager_migration_skip),
                    icon = Icons.Rounded.PlayArrow,
                    onClick = onSkip,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
            LegacyMigrationUiStage.Report -> {
                Text(
                    text = stringResource(R.string.voyager_migration_unsupported),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = state.unsupportedData.sorted().joinToString("\n"),
                    modifier = Modifier.padding(top = 16.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
                AutomotiveButton(
                    label = stringResource(R.string.voyager_continue),
                    icon = Icons.Rounded.PlayArrow,
                    onClick = onContinue,
                    modifier = Modifier.padding(top = 24.dp),
                )
            }
            LegacyMigrationUiStage.Ready -> Unit
        }
    }
}
