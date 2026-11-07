package com.voyager.voyager.core.plugin

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class PluginService {
    private val plugins = linkedMapOf<String, VoyagerPlugin>()
    private val _activeId = MutableStateFlow<String?>(null)
    val activeId: StateFlow<String?> = _activeId
    private val _drivingState = MutableStateFlow(DrivingState.UNKNOWN)
    val drivingState: StateFlow<DrivingState> = _drivingState

    val registered: List<VoyagerPlugin> get() = plugins.values.toList()
    val visible: List<VoyagerPlugin>
        get() = registered.filter { it.available.value }.sortedBy { it.manifest.order }
    val active: VoyagerPlugin? get() = _activeId.value?.let(plugins::get)
    val overlay: VoyagerPlugin?
        get() = registered
            .filter {
                it.available.value &&
                    it.manifest.providesOverlay &&
                    it.wantsOverlay.value &&
                    it.manifest.id != _activeId.value
            }
            .maxByOrNull { it.manifest.overlayPriority }

    fun register(plugin: VoyagerPlugin) {
        require(plugin.manifest.id !in plugins) { "Plugin '${plugin.manifest.id}' is already registered" }
        plugins[plugin.manifest.id] = plugin
        val allowedWhileDriving = plugin.manifest.drivingPolicy == DrivingPolicy.ALLOWED ||
            _drivingState.value == DrivingState.PARKED
        if (_activeId.value == null && plugin.manifest.canBeFullscreen && allowedWhileDriving) {
            _activeId.value = plugin.manifest.id
        }
    }

    suspend fun initializeAll() = coroutineScope {
        plugins.values.map { plugin -> async { plugin.initializeSafely() } }.awaitAll()
    }

    fun activate(id: String) {
        val plugin = plugins[id] ?: return
        if (!plugin.manifest.canBeFullscreen || !plugin.available.value || _activeId.value == id) return
        if (plugin.manifest.drivingPolicy == DrivingPolicy.PARKED_ONLY && _drivingState.value != DrivingState.PARKED) return
        active?.onVisibilityChanged(false)
        _activeId.value = id
        plugin.onVisibilityChanged(true)
    }

    fun setDrivingState(value: DrivingState) {
        if (_drivingState.value == value) return
        _drivingState.value = value
        if (value != DrivingState.PARKED && active?.manifest?.drivingPolicy == DrivingPolicy.PARKED_ONLY) {
            activate("navigation")
        }
    }

    fun dispatchButton(button: PhysicalButton): Boolean {
        val prioritized = listOfNotNull(overlay, active)
        val candidates = (prioritized + registered.filter { it.available.value })
            .distinctBy { it.manifest.id }
        return candidates.any { it.onPhysicalButtonPress(button) }
    }

    fun close() {
        plugins.values.forEach(VoyagerPlugin::close)
        plugins.clear()
        _activeId.value = null
    }
}
