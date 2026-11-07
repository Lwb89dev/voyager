package com.voyager.voyager.feature.music

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Album
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.AutomotiveButton
import com.voyager.voyager.core.ui.VoyagerColors
import kotlinx.coroutines.launch

@Composable
fun MusicScreen(plugin: MusicPlugin) {
    val state by plugin.state.collectAsStateWithLifecycle()
    val playback by plugin.playbackState.collectAsStateWithLifecycle()
    val parked by plugin.parked.collectAsStateWithLifecycle()
    var browserOpen by rememberSaveable { mutableStateOf(false) }
    val current = playback.current?.takeIf { it.source != MusicSource.PODCAST }

    BackHandler(enabled = browserOpen) { browserOpen = false }
    BoxWithConstraints(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground)) {
        when {
            current == null -> EmptyMusicState(
                state = state,
                onShuffle = plugin::shuffle,
                onBrowse = { browserOpen = true },
                onGrantPermission = plugin::requestPermission,
            )
            maxHeight < 420.dp -> CompactMusicPlayer(
                plugin = plugin,
                playback = playback,
                track = current,
                onBrowse = { browserOpen = true },
            )
            else -> Column(modifier = Modifier.fillMaxSize()) {
                Artwork(track = current, modifier = Modifier.weight(5f))
                NowPlaying(track = current, playback = playback, modifier = Modifier.weight(2f))
                MusicControls(
                    plugin = plugin,
                    isPlaying = playback.isPlaying,
                    onBrowse = { browserOpen = true },
                    modifier = Modifier.weight(3f),
                )
            }
        }
    }
    if (browserOpen) {
        Dialog(
            onDismissRequest = { browserOpen = false },
            properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
        ) {
            MusicLibraryBrowser(
                plugin = plugin,
                state = state,
                playback = playback,
                parked = parked,
                onClose = { browserOpen = false },
            )
        }
    }
}

@Composable
private fun Artwork(track: MusicTrack, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        if (track.artworkUrl == null) {
            Icon(
                imageVector = Icons.Rounded.Album,
                contentDescription = null,
                tint = VoyagerColors.Border,
                modifier = Modifier.size(140.dp),
            )
        } else {
            AsyncImage(
                model = track.artworkUrl,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize().padding(16.dp).clip(RoundedCornerShape(20.dp)),
            )
        }
    }
}

@Composable
private fun NowPlaying(track: MusicTrack, playback: PlaybackSnapshot, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = track.title,
            color = VoyagerColors.TextPrimary,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = track.artist,
            modifier = Modifier.padding(top = 4.dp),
            color = VoyagerColors.TextSecondary,
            fontSize = 20.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        MusicProgress(playback = playback, modifier = Modifier.padding(top = 14.dp))
    }
}

@Composable
private fun MusicProgress(playback: PlaybackSnapshot, modifier: Modifier = Modifier) {
    val progress = if (playback.durationMs > 0) {
        (playback.positionMs.toFloat() / playback.durationMs).coerceIn(0f, 1f)
    } else {
        0f
    }
    LinearProgressIndicator(
        progress = { progress },
        modifier = modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
        color = VoyagerColors.AccentMid,
        trackColor = VoyagerColors.SurfaceRaised,
    )
}

@Composable
private fun MusicControls(
    plugin: MusicPlugin,
    isPlaying: Boolean,
    onBrowse: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.Center) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            AutomotiveButton(label = stringResource(R.string.voyager_previous), icon = Icons.Rounded.SkipPrevious, onClick = plugin::previous, iconOnly = true)
            Spacer16()
            AutomotiveButton(
                label = stringResource(if (isPlaying) R.string.voyager_pause else R.string.voyager_play),
                icon = if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                onClick = plugin::playPause,
                selected = true,
                iconOnly = true,
            )
            Spacer16()
            AutomotiveButton(label = stringResource(R.string.voyager_next), icon = Icons.Rounded.SkipNext, onClick = plugin::next, iconOnly = true)
        }
        Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.Center) {
            AutomotiveButton(label = stringResource(R.string.voyager_shuffle), icon = Icons.Rounded.Shuffle, onClick = plugin::shuffle, iconOnly = true)
            Spacer16()
            AutomotiveButton(label = stringResource(R.string.voyager_library), icon = Icons.Rounded.LibraryMusic, onClick = onBrowse, iconOnly = true)
            Spacer16()
            AutomotiveButton(label = stringResource(R.string.voyager_stop), icon = Icons.Rounded.Close, onClick = plugin::stop, iconOnly = true)
        }
    }
}

@Composable
private fun Spacer16() = androidx.compose.foundation.layout.Spacer(modifier = Modifier.width(16.dp))

@Composable
private fun CompactMusicPlayer(
    plugin: MusicPlugin,
    playback: PlaybackSnapshot,
    track: MusicTrack,
    onBrowse: () -> Unit,
) {
    Row(modifier = Modifier.fillMaxSize().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
        if (track.artworkUrl == null) {
            Box(modifier = Modifier.size(96.dp), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Album, contentDescription = null, tint = VoyagerColors.Border, modifier = Modifier.size(48.dp))
            }
        } else {
            AsyncImage(
                model = track.artworkUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(96.dp).clip(RoundedCornerShape(14.dp)),
            )
        }
        Column(modifier = Modifier.weight(1f).padding(start = 16.dp)) {
            Text(track.title, color = VoyagerColors.TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(track.artist, color = VoyagerColors.TextSecondary, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            MusicProgress(playback = playback, modifier = Modifier.padding(top = 8.dp))
        }
        Row(modifier = Modifier.padding(start = 12.dp)) {
            CompactControl(stringResource(R.string.voyager_previous), Icons.Rounded.SkipPrevious, plugin::previous)
            CompactControl(
                stringResource(if (playback.isPlaying) R.string.voyager_pause else R.string.voyager_play),
                if (playback.isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                plugin::playPause,
                selected = true,
            )
            CompactControl(stringResource(R.string.voyager_next), Icons.Rounded.SkipNext, plugin::next)
            CompactControl(stringResource(R.string.voyager_library), Icons.Rounded.LibraryMusic, onBrowse)
            CompactControl(stringResource(R.string.voyager_stop), Icons.Rounded.Close, plugin::stop)
        }
    }
}

@Composable
private fun CompactControl(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    selected: Boolean = false,
) {
    Box(
        modifier = Modifier
            .padding(start = 4.dp)
            .size(52.dp)
            .background(if (selected) VoyagerColors.Accent.copy(alpha = 0.2f) else androidx.compose.ui.graphics.Color.Transparent, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = if (selected) VoyagerColors.AccentLight else VoyagerColors.TextPrimary,
            modifier = Modifier.size(24.dp),
        )
    }
}

@Composable
private fun EmptyMusicState(
    state: MusicUiState,
    onShuffle: () -> Unit,
    onBrowse: () -> Unit,
    onGrantPermission: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = if (state.albums.isEmpty()) stringResource(R.string.voyager_no_music_found) else stringResource(R.string.voyager_albums_available, state.albums.size),
                color = VoyagerColors.TextSecondary,
                fontSize = 20.sp,
                textAlign = TextAlign.Center,
            )
            if (state.error != null) {
                Text(
                    text = state.error,
                    modifier = Modifier.padding(top = 12.dp),
                    color = VoyagerColors.Error,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
                if (state.error.contains("permission", ignoreCase = true)) {
                    OutlinedButton(onClick = onGrantPermission, modifier = Modifier.padding(top = 12.dp)) {
                        Text(stringResource(R.string.voyager_grant_audio))
                    }
                }
            }
            Button(
                onClick = onShuffle,
                enabled = state.albums.isNotEmpty() && !state.loading,
                modifier = Modifier.padding(top = 24.dp),
                contentPadding = PaddingValues(horizontal = 40.dp, vertical = 26.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Icon(Icons.Rounded.Shuffle, contentDescription = null, modifier = Modifier.size(32.dp))
                Text(stringResource(R.string.voyager_play_something), modifier = Modifier.padding(start = 12.dp), fontSize = 28.sp, fontWeight = FontWeight.Bold)
            }
            OutlinedButton(
                onClick = onBrowse,
                enabled = state.albums.isNotEmpty(),
                modifier = Modifier.padding(top = 16.dp),
                contentPadding = PaddingValues(horizontal = 32.dp, vertical = 18.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Icon(Icons.Rounded.LibraryMusic, contentDescription = null, modifier = Modifier.size(26.dp))
                Text(stringResource(R.string.voyager_browse_library), modifier = Modifier.padding(start = 12.dp), fontSize = 20.sp)
            }
            if (state.loading) CircularProgressIndicator(modifier = Modifier.padding(top = 24.dp))
        }
    }
}

@Composable
private fun MusicLibraryBrowser(
    plugin: MusicPlugin,
    state: MusicUiState,
    playback: PlaybackSnapshot,
    parked: Boolean,
    onClose: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    Column(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).statusBarsPadding()) {
        Row(modifier = Modifier.fillMaxWidth().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onClose) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.voyager_back), tint = VoyagerColors.TextPrimary)
            }
            Text(stringResource(R.string.voyager_browse_library), modifier = Modifier.weight(1f), color = VoyagerColors.TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            IconButton(onClick = plugin::cycleRepeat) {
                Icon(
                    imageVector = if (playback.repeatMode == androidx.media3.common.Player.REPEAT_MODE_ONE) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat,
                    contentDescription = stringResource(R.string.voyager_repeat),
                    tint = if (playback.repeatMode == androidx.media3.common.Player.REPEAT_MODE_OFF) VoyagerColors.TextSecondary else VoyagerColors.AccentLight,
                )
            }
            IconButton(onClick = { scope.launch { plugin.reload() } }, enabled = !state.loading) {
                Icon(Icons.Rounded.Refresh, contentDescription = stringResource(R.string.voyager_refresh), tint = VoyagerColors.TextPrimary)
            }
        }
        if (parked) {
            OutlinedTextField(
                value = query,
                onValueChange = {
                    query = it
                    plugin.search(it)
                },
                modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
                singleLine = true,
                label = { Text(stringResource(R.string.voyager_search_music)) },
            )
        }
        if (state.loading) CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally).padding(12.dp))
        val results = state.searchResults
        LazyColumn(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (results != null) {
                items(results, key = { "${it.source}:${it.id}" }) { track ->
                    BrowserTrackRow(track = track, onClick = {
                        plugin.playTrack(track)
                        onClose()
                    })
                }
            } else {
                items(state.albums, key = { "${it.source}:${it.id}" }) { album ->
                    BrowserAlbumRow(album = album, onClick = {
                        plugin.playAlbum(album.id)
                        onClose()
                    })
                }
            }
        }
    }
}

@Composable
private fun BrowserAlbumRow(album: MusicAlbum, onClick: () -> Unit) {
    BrowserRow(
        icon = { Icon(Icons.Rounded.Album, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(24.dp)) },
        title = album.name,
        subtitle = album.artist.ifBlank { null },
        onClick = onClick,
        trailing = {
            IconButton(onClick = onClick) {
                Icon(Icons.Rounded.PlayArrow, contentDescription = stringResource(R.string.voyager_play), tint = VoyagerColors.AccentLight, modifier = Modifier.size(30.dp))
            }
        },
    )
}

@Composable
private fun BrowserTrackRow(track: MusicTrack, onClick: () -> Unit) {
    BrowserRow(
        icon = { Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(24.dp)) },
        title = track.title,
        subtitle = track.artist.ifBlank { null },
        onClick = onClick,
    )
}

@Composable
private fun BrowserRow(
    icon: @Composable () -> Unit,
    title: String,
    subtitle: String?,
    onClick: () -> Unit,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        icon()
        Column(modifier = Modifier.weight(1f).padding(start = 14.dp)) {
            Text(title, color = VoyagerColors.TextPrimary, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) Text(subtitle, color = VoyagerColors.TextSecondary, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        trailing?.invoke()
    }
}
