package com.voyager.voyager.feature.podcast

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddCircleOutline
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.PlayCircleOutline
import androidx.compose.material.icons.rounded.Podcasts
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.voyager.voyager.R
import com.voyager.voyager.core.ui.VoyagerColors
import com.voyager.voyager.feature.music.MusicSource
import com.voyager.voyager.feature.music.PlaybackSnapshot
import java.text.DateFormat
import java.util.Date

@Composable
fun PodcastScreen(plugin: PodcastPlugin) {
    val state by plugin.state.collectAsStateWithLifecycle()
    val playback by plugin.playbackState.collectAsStateWithLifecycle()
    var addOpen by rememberSaveable { mutableStateOf(false) }
    val selected = state.selected

    BackHandler(enabled = addOpen || selected != null) {
        if (addOpen) addOpen = false else plugin.closeEpisodes()
    }
    PodcastSubscriptionsScreen(
        state = state,
        playback = playback,
        onOpen = plugin::open,
        onAdd = { addOpen = true },
        onPrevious = plugin::previous,
        onPlayPause = plugin::playPause,
        onNext = plugin::next,
        onStop = plugin::stop,
    )
    if (addOpen) {
        Dialog(
            onDismissRequest = { addOpen = false },
            properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
        ) {
            AddPodcastScreen(
                state = state,
                onSubmit = plugin::submit,
                onSubscribe = {
                    plugin.subscribe(it)
                    addOpen = false
                },
                onClose = { addOpen = false },
            )
        }
    }
    if (selected != null) {
        Dialog(
            onDismissRequest = plugin::closeEpisodes,
            properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
        ) {
            PodcastEpisodesScreen(
                state = state,
                podcast = selected,
                onPlay = {
                    plugin.play(it)
                    plugin.closeEpisodes()
                },
                onUnsubscribe = { plugin.unsubscribe(selected.feedUrl) },
                onClose = plugin::closeEpisodes,
            )
        }
    }
}

@Composable
private fun PodcastSubscriptionsScreen(
    state: PodcastUiState,
    playback: PlaybackSnapshot,
    onOpen: (PodcastSubscription) -> Unit,
    onAdd: () -> Unit,
    onPrevious: () -> Unit,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onStop: () -> Unit,
) {
    val current = playback.current?.takeIf { it.source == MusicSource.PODCAST }
    Column(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).statusBarsPadding()) {
        if (current != null) {
            PodcastNowPlayingBar(
                playback = playback,
                onPrevious = onPrevious,
                onPlayPause = onPlayPause,
                onNext = onNext,
                onStop = onStop,
            )
        }
        if (state.subscriptions.isEmpty()) {
            EmptyPodcasts(onAdd = onAdd, modifier = Modifier.weight(1f))
        } else {
            LazyColumn(modifier = Modifier.weight(1f).fillMaxWidth().padding(vertical = 8.dp)) {
                items(state.subscriptions, key = { it.feedUrl }) { podcast ->
                    PodcastSubscriptionRow(podcast = podcast, onClick = { onOpen(podcast) })
                }
            }
            Box(modifier = Modifier.fillMaxWidth().padding(12.dp), contentAlignment = Alignment.Center) {
                OutlinedButton(
                    onClick = onAdd,
                    contentPadding = PaddingValues(horizontal = 24.dp, vertical = 14.dp),
                    shape = RoundedCornerShape(24.dp),
                ) {
                    Icon(Icons.Rounded.Add, contentDescription = null)
                    Text(stringResource(R.string.voyager_add_podcast), modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun EmptyPodcasts(onAdd: () -> Unit, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Icon(Icons.Rounded.Podcasts, contentDescription = null, tint = VoyagerColors.TextSecondary, modifier = Modifier.size(56.dp))
        Text(
            text = stringResource(R.string.voyager_no_subscriptions),
            modifier = Modifier.padding(top = 16.dp),
            color = VoyagerColors.TextSecondary,
            fontSize = 20.sp,
            textAlign = TextAlign.Center,
        )
        Button(
            onClick = onAdd,
            modifier = Modifier.padding(top = 24.dp),
            contentPadding = PaddingValues(horizontal = 32.dp, vertical = 20.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            Icon(Icons.Rounded.Add, contentDescription = null, modifier = Modifier.size(28.dp))
            Text(stringResource(R.string.voyager_add_podcast), modifier = Modifier.padding(start = 12.dp), fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun PodcastSubscriptionRow(podcast: PodcastSubscription, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 76.dp).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Podcasts, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(26.dp))
        Text(
            text = podcast.title,
            modifier = Modifier.weight(1f).padding(start = 14.dp),
            color = VoyagerColors.TextPrimary,
            fontSize = 20.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Icon(Icons.Rounded.ChevronRight, contentDescription = null, tint = VoyagerColors.TextSecondary)
    }
}

@Composable
private fun PodcastNowPlayingBar(
    playback: PlaybackSnapshot,
    onPrevious: () -> Unit,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onStop: () -> Unit,
) {
    val track = playback.current ?: return
    Column(modifier = Modifier.fillMaxWidth().background(VoyagerColors.Surface).padding(start = 16.dp, top = 12.dp, end = 12.dp, bottom = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Podcasts, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(26.dp))
            Column(modifier = Modifier.weight(1f).padding(start = 12.dp)) {
                Text(track.title, color = VoyagerColors.TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(track.artist, color = VoyagerColors.TextSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            PodcastControl(stringResource(R.string.voyager_previous), Icons.Rounded.SkipPrevious, onPrevious)
            PodcastControl(
                stringResource(if (playback.isPlaying) R.string.voyager_pause else R.string.voyager_play),
                if (playback.isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                onPlayPause,
                selected = true,
            )
            PodcastControl(stringResource(R.string.voyager_next), Icons.Rounded.SkipNext, onNext)
            PodcastControl(stringResource(R.string.voyager_stop), Icons.Rounded.Close, onStop)
        }
        val progress = if (playback.durationMs > 0) (playback.positionMs.toFloat() / playback.durationMs).coerceIn(0f, 1f) else 0f
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp).height(6.dp).clip(RoundedCornerShape(4.dp)),
            color = VoyagerColors.AccentMid,
            trackColor = VoyagerColors.SurfaceRaised,
        )
    }
    Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(VoyagerColors.Border))
}

@Composable
private fun PodcastControl(label: String, icon: ImageVector, onClick: () -> Unit, selected: Boolean = false) {
    Box(
        modifier = Modifier
            .padding(start = 4.dp)
            .size(48.dp)
            .background(if (selected) VoyagerColors.Accent.copy(alpha = 0.2f) else androidx.compose.ui.graphics.Color.Transparent, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = if (selected) VoyagerColors.AccentLight else VoyagerColors.TextPrimary, modifier = Modifier.size(22.dp))
    }
}

@Composable
private fun AddPodcastScreen(
    state: PodcastUiState,
    onSubmit: (String) -> Unit,
    onSubscribe: (PodcastSubscription) -> Unit,
    onClose: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    val byUrl = query.trim().startsWith("https://") || query.trim().startsWith("http://")
    Column(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).statusBarsPadding()) {
        PodcastTopBar(title = stringResource(R.string.voyager_add_podcast), onClose = onClose)
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            TextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.weight(1f),
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                placeholder = { Text(stringResource(R.string.voyager_search_or_feed_url)) },
                colors = TextFieldDefaults.colors(
                    focusedTextColor = VoyagerColors.TextPrimary,
                    unfocusedTextColor = VoyagerColors.TextPrimary,
                    focusedContainerColor = VoyagerColors.Surface,
                    unfocusedContainerColor = VoyagerColors.Surface,
                    focusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
                    unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
                ),
            )
            Button(
                onClick = {
                    onSubmit(query)
                    if (byUrl) onClose()
                },
                enabled = query.isNotBlank() && !state.loading,
                modifier = Modifier.padding(start = 12.dp),
            ) {
                Text(stringResource(if (byUrl) R.string.voyager_add else R.string.voyager_search))
            }
        }
        state.error?.let { Text(it, modifier = Modifier.padding(horizontal = 16.dp), color = VoyagerColors.Error, fontSize = 13.sp) }
        if (state.loading) CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally).padding(24.dp))
        LazyColumn(modifier = Modifier.weight(1f).fillMaxWidth()) {
            items(state.directoryResults.orEmpty(), key = { it.feedUrl }) { podcast ->
                Row(modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Podcasts, contentDescription = null, tint = VoyagerColors.AccentLight)
                    Text(podcast.title, modifier = Modifier.weight(1f).padding(start = 16.dp), color = VoyagerColors.TextPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    IconButton(onClick = { onSubscribe(podcast) }) {
                        Icon(Icons.Rounded.AddCircleOutline, contentDescription = stringResource(R.string.voyager_add), tint = VoyagerColors.AccentLight)
                    }
                }
            }
        }
    }
}

@Composable
private fun PodcastEpisodesScreen(
    state: PodcastUiState,
    podcast: PodcastSubscription,
    onPlay: (PodcastEpisode) -> Unit,
    onUnsubscribe: () -> Unit,
    onClose: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxSize().background(VoyagerColors.Ground).statusBarsPadding()) {
        PodcastTopBar(
            title = podcast.title,
            onClose = onClose,
            action = {
                IconButton(onClick = onUnsubscribe) {
                    Icon(Icons.Rounded.DeleteOutline, contentDescription = stringResource(R.string.voyager_unsubscribe), tint = VoyagerColors.TextPrimary)
                }
            },
        )
        state.error?.let { Text(it, modifier = Modifier.padding(16.dp), color = VoyagerColors.Error) }
        if (state.episodesFromCache) {
            Text(stringResource(R.string.voyager_podcast_cached), modifier = Modifier.padding(horizontal = 16.dp), color = VoyagerColors.TextSecondary)
        }
        if (state.loading) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = VoyagerColors.Accent)
            }
        } else if (state.episodes.isEmpty()) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.voyager_no_episodes), color = VoyagerColors.TextSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(modifier = Modifier.weight(1f).fillMaxWidth()) {
                items(state.episodes, key = { it.guid }) { episode -> PodcastEpisodeRow(episode = episode, onClick = { onPlay(episode) }) }
            }
        }
    }
}

@Composable
private fun PodcastTopBar(title: String, onClose: () -> Unit, action: (@Composable () -> Unit)? = null) {
    Row(modifier = Modifier.fillMaxWidth().height(64.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onClose) {
            Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.voyager_back), tint = VoyagerColors.TextPrimary)
        }
        Text(title, modifier = Modifier.weight(1f), color = VoyagerColors.TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        action?.invoke()
    }
}

@Composable
private fun PodcastEpisodeRow(episode: PodcastEpisode, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 76.dp).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.PlayCircleOutline, contentDescription = null, tint = VoyagerColors.AccentLight, modifier = Modifier.size(30.dp))
        Column(modifier = Modifier.weight(1f).padding(start = 14.dp)) {
            Text(episode.title, color = VoyagerColors.TextPrimary, fontSize = 16.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
            val details = buildList {
                episode.publishedEpochMs?.let { add(DateFormat.getDateInstance().format(Date(it))) }
                if (episode.durationMs > 0) add("${episode.durationMs / 60_000} min")
            }.joinToString(" · ")
            if (details.isNotEmpty()) Text(details, modifier = Modifier.padding(top = 2.dp), color = VoyagerColors.TextSecondary, fontSize = 13.sp)
        }
    }
}
