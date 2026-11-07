package com.voyager.voyager.feature.weather

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.runtime.Composable
import com.voyager.voyager.R
import com.voyager.voyager.core.plugin.PluginManifest
import com.voyager.voyager.core.plugin.VoyagerPlugin
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

data class WeatherUiState(
    val data: WeatherData? = null,
    val placeName: String? = null,
    val loading: Boolean = false,
    val waitingForLocation: Boolean = true,
    val stale: Boolean = false,
    val error: Boolean = false,
)

class WeatherPlugin(
    context: Context,
    private val repository: WeatherRepository,
    private val clock: () -> Long = System::currentTimeMillis,
) : VoyagerPlugin() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val refreshMutex = Mutex()
    private var pollJob: Job? = null
    private var location: WeatherLocation? = null
    private val _state = MutableStateFlow(WeatherUiState())
    val state: StateFlow<WeatherUiState> = _state

    override val manifest = PluginManifest(
        id = ID,
        label = R.string.voyager_weather,
        icon = Icons.Rounded.Cloud,
        order = 3,
    )

    constructor(context: Context) : this(
        context = context,
        repository = WeatherRepository(cache = SharedPreferencesWeatherCache(context)),
    )

    override suspend fun initialize() {
        val cached = withContext(Dispatchers.IO) { repository.cached() }
        _state.value = _state.value.copy(data = cached, stale = cached != null)
    }

    fun setLocation(value: WeatherLocation) {
        val changed = location != value
        location = value
        val cached = _state.value.data
        if (changed && cached != null && WeatherRefreshPolicy.distanceMeters(cached.location, value) >= WeatherRefreshPolicy.DISTANCE_METERS) {
            _state.value = _state.value.copy(data = null, placeName = null, stale = false)
        }
        _state.value = _state.value.copy(waitingForLocation = false)
        if (changed && pollJob?.isActive == true) refresh()
    }

    override fun onVisibilityChanged(visible: Boolean) {
        pollJob?.cancel()
        if (!visible) return
        pollJob = scope.launch {
            refresh()
            while (isActive) {
                delay(WeatherRefreshPolicy.INTERVAL_MS)
                refresh()
            }
        }
    }

    fun refresh(force: Boolean = false) {
        scope.launch { refreshNow(force) }
    }

    private suspend fun refreshNow(force: Boolean) = refreshMutex.withLock {
        val currentLocation = location
        if (currentLocation == null) {
            _state.value = _state.value.copy(waitingForLocation = true, loading = false)
            return
        }
        val now = clock()
        if (!WeatherRefreshPolicy.needsRefresh(_state.value.data, currentLocation, now, force)) return
        _state.value = _state.value.copy(loading = true, error = false)
        try {
            val data = withContext(Dispatchers.IO) { repository.fetch(currentLocation, now) }
            _state.value = _state.value.copy(
                data = data,
                placeName = null,
                loading = false,
                waitingForLocation = false,
                stale = false,
                error = false,
            )
            try {
                val place = withContext(Dispatchers.IO) { repository.placeName(currentLocation) }
                if (location == currentLocation && _state.value.data == data) {
                    _state.value = _state.value.copy(placeName = place)
                }
            } catch (error: Throwable) {
                if (error is CancellationException) throw error
            }
        } catch (error: Throwable) {
            if (error is CancellationException) throw error
            _state.value = _state.value.copy(
                loading = false,
                stale = _state.value.data != null,
                error = true,
            )
        }
    }

    @Composable
    override fun FullscreenContent() = WeatherScreen(this)

    override fun close() {
        pollJob?.cancel()
        scope.cancel()
    }

    companion object {
        const val ID = "weather"
    }
}
