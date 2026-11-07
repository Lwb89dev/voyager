package com.voyager.voyager

import android.Manifest
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import androidx.activity.compose.BackHandler
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import app.roadstr.feature.home.NativeShellMode
import app.roadstr.roadtest.NativeLiveStoreNames
import app.roadstr.roadtest.NativeNavigationRuntime
import app.roadstr.roadtest.NativeRoadTestActivity
import app.roadstr.startup.NativeGuidanceRuntimeHolder
import androidx.media3.common.util.UnstableApi
import com.voyager.voyager.core.plugin.DrivingPolicyController
import com.voyager.voyager.core.plugin.DrivingState
import com.voyager.voyager.core.plugin.PhysicalButton
import com.voyager.voyager.core.plugin.PhysicalKeyMapper
import com.voyager.voyager.core.plugin.PluginService
import com.voyager.voyager.core.ui.VoyagerTheme
import com.voyager.voyager.feature.dashboard.AutomotiveDashboard
import com.voyager.voyager.feature.dashboard.AutomotiveSettingsScreen
import com.voyager.voyager.feature.dashboard.AutomotiveUiController
import com.voyager.voyager.feature.dashboard.NavigationPlugin
import com.voyager.voyager.feature.music.MusicPlugin
import com.voyager.voyager.feature.music.MusicSource
import com.voyager.voyager.feature.music.PlaybackStateBus
import com.voyager.voyager.feature.phone.PhonePlugin
import com.voyager.voyager.feature.podcast.PodcastPlugin
import com.voyager.voyager.feature.voice.VoiceCommandDispatcher
import com.voyager.voyager.feature.voice.VoicePlugin
import com.voyager.voyager.feature.weather.WeatherLocation
import com.voyager.voyager.feature.weather.WeatherPlugin
import com.voyager.voyager.legacy.migration.AndroidVoyagerLegacyReader
import com.voyager.voyager.legacy.migration.AndroidVoyagerLegacyTarget
import com.voyager.voyager.legacy.migration.LegacyMigrationScreen
import com.voyager.voyager.legacy.migration.LegacyMigrationUiStage
import com.voyager.voyager.legacy.migration.LegacyMigrationUiState
import com.voyager.voyager.legacy.migration.SharedPreferencesVoyagerLegacyMigrationMarker
import com.voyager.voyager.legacy.migration.VoyagerLegacyMigration
import com.voyager.voyager.legacy.migration.VoyagerLegacyMigrationOutcome
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

@UnstableApi
class MainActivity : NativeRoadTestActivity() {
    override val storeNames: NativeLiveStoreNames = NativeLiveStoreNames(NativeLiveStoreNames.LIVE)
    override val shellMode: NativeShellMode = NativeShellMode.App
    override val maximumScreenBrightness: Double = 0.75

    private val notificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {}
    private var notificationsAsked = false
    private var musicPlugin: MusicPlugin? = null
    private val audioPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) musicPlugin?.let { plugin -> lifecycleScope.launch { plugin.reload() } }
    }
    private var voicePlugin: VoicePlugin? = null
    private var pluginService: PluginService? = null
    private var closeSettings: (() -> Unit)? = null
    private var expandChrome: (() -> Unit)? = null
    private val keyPreferences by lazy { getSharedPreferences("voyager_automotive", MODE_PRIVATE) }
    private val microphonePermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> voicePlugin?.onMicrophonePermission(granted) }
    private val legacyMigrationState = MutableStateFlow(LegacyMigrationUiState())
    private var legacyMigrationJob: Job? = null

    override fun obtainRuntime(): NativeNavigationRuntime =
        NativeGuidanceRuntimeHolder.obtain(applicationContext, storeNames)

    override fun releaseRuntime(runtime: NativeNavigationRuntime) =
        NativeGuidanceRuntimeHolder.release(runtime)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startLegacyMigration()
        val runtime = NativeGuidanceRuntimeHolder.obtain(applicationContext, storeNames)
        lifecycleScope.launch {
            runtime.host.session.state
                .map { it.active }
                .distinctUntilChanged()
                .filter { it }
                .collect { askForNotifications() }
        }
        lifecycleScope.launch {
            runtime.transitSession.state
                .map { it.active }
                .distinctUntilChanged()
                .filter { it }
                .collect { askForNotifications() }
        }
    }

    @Composable
    override fun RoadstrContent() {
        val migration by legacyMigrationState.collectAsStateWithLifecycle()
        if (migration.stage != LegacyMigrationUiStage.Ready) {
            VoyagerTheme {
                LegacyMigrationScreen(
                    state = migration,
                    onRetry = ::startLegacyMigration,
                    onSkip = ::skipLegacyMigration,
                    onContinue = {
                        legacyMigrationState.value = LegacyMigrationUiState(LegacyMigrationUiStage.Ready)
                    },
                )
            }
            return
        }
        VoyagerTheme {
            val ui = remember { AutomotiveUiController(this@MainActivity) }
            val driving = remember { DrivingPolicyController() }
            val uiState by ui.state.collectAsStateWithLifecycle()
            val onboardingPreferences = remember {
                getSharedPreferences(storeNames.prefs("onboarding"), MODE_PRIVATE)
            }
            var onboardingCompleted by remember {
                mutableStateOf(onboardingPreferences.getBoolean("completed", false))
            }
            DisposableEffect(onboardingPreferences) {
                val listener = SharedPreferences.OnSharedPreferenceChangeListener { preferences, key ->
                    if (key == "completed") {
                        onboardingCompleted = preferences.getBoolean("completed", false)
                    }
                }
                onboardingPreferences.registerOnSharedPreferenceChangeListener(listener)
                onDispose { onboardingPreferences.unregisterOnSharedPreferenceChangeListener(listener) }
            }
            var settingsOpen by remember { mutableStateOf(false) }
            closeSettings = { settingsOpen = false }
            BackHandler(enabled = settingsOpen) { settingsOpen = false }
            var remapVolume by remember {
                mutableStateOf(keyPreferences.getBoolean(KEY_REMAP_VOLUME, false))
            }
            var chromeCollapsed by remember {
                mutableStateOf(keyPreferences.getBoolean(KEY_CHROME_COLLAPSED, false))
            }
            expandChrome = {
                chromeCollapsed = false
                keyPreferences.edit().putBoolean(KEY_CHROME_COLLAPSED, false).apply()
            }
            val view = LocalView.current
            LaunchedEffect(ui) { ui.initialize() }
            DisposableEffect(ui) { onDispose(ui::close) }
            DisposableEffect(view, uiState.keepAwake) {
                view.keepScreenOn = uiState.keepAwake
                onDispose { view.keepScreenOn = false }
            }
            val plugins = remember {
                PluginService().apply {
                    register(NavigationPlugin { super.RoadstrContent() })
                    val music = MusicPlugin(this@MainActivity, ::requestAudioPermission)
                    musicPlugin = music
                    register(music)
                    val podcast = PodcastPlugin(this@MainActivity)
                    register(podcast)
                    val weather = WeatherPlugin(this@MainActivity)
                    register(weather)
                    val phone = PhonePlugin(this@MainActivity)
                    register(phone)
                    val voice = VoicePlugin(
                        speechProvider = { speechGateway },
                        dispatcher = VoiceCommandDispatcher(
                            playMusic = music::shuffle,
                            playPause = {
                                if (PlaybackStateBus.state.value.current?.source == MusicSource.PODCAST) {
                                    podcast.playPause()
                                } else {
                                    music.playPause()
                                }
                            },
                            nextTrack = {
                                if (PlaybackStateBus.state.value.current?.source == MusicSource.PODCAST) {
                                    podcast.next()
                                } else {
                                    music.next()
                                }
                            },
                            previousTrack = {
                                if (PlaybackStateBus.state.value.current?.source == MusicSource.PODCAST) {
                                    podcast.previous()
                                } else {
                                    music.previous()
                                }
                            },
                            showNavigation = { activate(NavigationPlugin.ID) },
                            showWeather = { activate(WeatherPlugin.ID) },
                            answerCall = phone::answer,
                            rejectCall = phone::reject,
                        ),
                        languageTag = { resources.configuration.locales[0].toLanguageTag() },
                        hasMicrophonePermission = {
                            ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO,
                            ) == PackageManager.PERMISSION_GRANTED
                        },
                        requestMicrophonePermission = {
                            microphonePermission.launch(Manifest.permission.RECORD_AUDIO)
                        },
                        stopGuidance = { voiceGateway.stop() },
                    )
                    voicePlugin = voice
                    register(voice)
                    lifecycleScope.launch {
                        NativeGuidanceRuntimeHolder.obtain(applicationContext, storeNames)
                            .location.state.collect { snapshot ->
                                val fix = snapshot.fix
                                val drivingState = driving.update(fix?.speedMetersPerSecond)
                                music.setParked(drivingState == DrivingState.PARKED)
                                setDrivingState(drivingState)
                                if (fix != null) {
                                    weather.setLocation(
                                        WeatherLocation(fix.point.latitude, fix.point.longitude),
                                    )
                                    ui.setLocation(fix.point.latitude, fix.point.longitude)
                                }
                            }
                    }
                }
            }
            pluginService = plugins
            LaunchedEffect(plugins) { plugins.initializeAll() }
            DisposableEffect(plugins) { onDispose(plugins::close) }
            Box(modifier = Modifier.fillMaxSize()) {
                AutomotiveDashboard(
                    plugins = plugins,
                    navigationContent = { super.RoadstrContent() },
                    onOpenSettings = { settingsOpen = true },
                    chromeVisible = onboardingCompleted,
                    collapsed = chromeCollapsed,
                    onToggleCollapsed = {
                        chromeCollapsed = !chromeCollapsed
                        keyPreferences.edit().putBoolean(KEY_CHROME_COLLAPSED, chromeCollapsed).apply()
                    },
                )
                if (settingsOpen) {
                    AutomotiveSettingsScreen(
                        state = uiState,
                        remapVolumeKeys = remapVolume,
                        onKeepAwakeChange = ui::setKeepAwake,
                        onNightDimmingChange = ui::setNightDimming,
                        onRemapVolumeChange = { enabled ->
                            keyPreferences.edit().putBoolean(KEY_REMAP_VOLUME, enabled).apply()
                            remapVolume = enabled
                        },
                        onClose = { settingsOpen = false },
                    )
                }
                if (uiState.dimOpacity > 0) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = uiState.dimOpacity)),
                    )
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return super.dispatchKeyEvent(event)
        val remapVolume = keyPreferences.getBoolean(KEY_REMAP_VOLUME, false)
        val button = PhysicalKeyMapper.buttonFor(event.keyCode, remapVolume)
            ?: return super.dispatchKeyEvent(event)
        if (event.repeatCount > 0 && button == PhysicalButton.VOICE) return true
        var handled = pluginService?.dispatchButton(button) == true
        if (!handled && button == PhysicalButton.MENU) {
            closeSettings?.invoke()
            expandChrome?.invoke()
            pluginService?.activate(NavigationPlugin.ID)
            handled = pluginService != null
        }
        return if (handled) true else super.dispatchKeyEvent(event)
    }

    @Composable
    override fun SpeechOverlayHost() {
        val voiceActive = voicePlugin?.wantsOverlay?.collectAsStateWithLifecycle()?.value == true
        if (!voiceActive) super.SpeechOverlayHost()
    }

    private fun startLegacyMigration() {
        if (legacyMigrationJob?.isActive == true) return
        legacyMigrationState.value = LegacyMigrationUiState()
        legacyMigrationJob = lifecycleScope.launch(Dispatchers.IO) {
            val result = VoyagerLegacyMigration(
                reader = AndroidVoyagerLegacyReader(applicationContext),
                target = AndroidVoyagerLegacyTarget(applicationContext, storeNames),
                marker = SharedPreferencesVoyagerLegacyMigrationMarker(applicationContext),
            ).run()
            legacyMigrationState.value = when {
                result.outcome == VoyagerLegacyMigrationOutcome.Failed -> {
                    LegacyMigrationUiState(LegacyMigrationUiStage.Failed)
                }
                result.outcome == VoyagerLegacyMigrationOutcome.Migrated && result.unsupportedData.isNotEmpty() -> {
                    LegacyMigrationUiState(LegacyMigrationUiStage.Report, result.unsupportedData)
                }
                else -> LegacyMigrationUiState(LegacyMigrationUiStage.Ready)
            }
        }
    }

    private fun skipLegacyMigration() {
        if (legacyMigrationJob?.isActive == true) return
        legacyMigrationState.value = LegacyMigrationUiState()
        legacyMigrationJob = lifecycleScope.launch(Dispatchers.IO) {
            val skipped = runCatching {
                SharedPreferencesVoyagerLegacyMigrationMarker(applicationContext)
                    .markComplete(setOf("user_skipped"))
            }.isSuccess
            legacyMigrationState.value = LegacyMigrationUiState(
                if (skipped) LegacyMigrationUiStage.Ready else LegacyMigrationUiStage.Failed,
            )
        }
    }

    private fun requestAudioPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        audioPermission.launch(permission)
    }

    private fun askForNotifications() {
        if (notificationsAsked || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        notificationsAsked = true
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    companion object {
        private const val KEY_REMAP_VOLUME = "remap_volume_keys"
        private const val KEY_CHROME_COLLAPSED = "voyager_chrome_collapsed"
    }
}
