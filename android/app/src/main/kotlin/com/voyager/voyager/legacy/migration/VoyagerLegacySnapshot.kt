package com.voyager.voyager.legacy.migration

import com.voyager.voyager.core.network.ServerUrlPolicy
import com.voyager.voyager.feature.music.EqualizerPreset
import com.voyager.voyager.feature.music.EqualizerSettings
import com.voyager.voyager.feature.music.MusicBackend
import com.voyager.voyager.feature.music.MusicConfiguration
import com.voyager.voyager.feature.podcast.PodcastSubscription

data class VoyagerLegacySnapshot(
    val music: MusicConfiguration,
    val podcasts: List<PodcastSubscription>,
    val equalizer: EqualizerSettings,
    val nightDimming: Boolean,
    val remapVolume: Boolean,
    val onboardingCompleted: Boolean,
    val unsupportedData: Set<String>,
) {
    override fun toString(): String =
        "VoyagerLegacySnapshot(podcasts=${podcasts.size}, unsupported=$unsupportedData)"
}

object VoyagerLegacySnapshotMapper {
    fun map(values: Map<String, Any?>): VoyagerLegacySnapshot {
        val unsupported = linkedSetOf<String>()
        values.keys.filter { it.startsWith("voyager_") && it !in SUPPORTED_KEYS }
            .forEach { unsupported += "hive:$it" }
        if (values.keys.any { !it.startsWith("voyager_") }) unsupported += "roadstr:profile_pending"
        val music = musicConfiguration(values, unsupported)
        val podcasts = podcastSubscriptions(values["voyager_podcast_subscriptions"])
        val gains = values["voyager_eq_gains"]?.let { raw ->
            require(raw is List<*> && raw.size <= MAX_EQUALIZER_BANDS) { "Invalid equalizer gains" }
            raw.map { value ->
                require(value is Number) { "Invalid equalizer gain" }
                value.toDouble().also { require(it.isFinite() && it in -100.0..100.0) { "Invalid equalizer gain" } }
            }
        }
        val preset = when (val stored = optionalString(values, "voyager_eq_preset") ?: "flat") {
            "roadNoise" -> EqualizerPreset.ROAD_NOISE
            else -> runCatching { EqualizerPreset.valueOf(stored.uppercase()) }
                .getOrElse { throw IllegalArgumentException("Unsupported equalizer preset") }
        }
        return VoyagerLegacySnapshot(
            music = music,
            podcasts = podcasts,
            equalizer = EqualizerSettings(
                enabled = boolean(values, "voyager_eq_enabled", false),
                preset = preset,
                gains = gains,
            ),
            nightDimming = boolean(values, "voyager_night_dimming", true),
            remapVolume = boolean(values, "voyager_remap_volume", false),
            onboardingCompleted = boolean(values, "voyager_onboarding_done", false),
            unsupportedData = unsupported,
        )
    }

    private fun musicConfiguration(
        values: Map<String, Any?>,
        unsupported: MutableSet<String>,
    ): MusicConfiguration {
        val navidrome = MusicConfiguration(
            backend = MusicBackend.NAVIDROME,
            endpoint = optionalString(values, "voyager_navidrome_endpoint").orEmpty(),
            username = optionalString(values, "voyager_navidrome_username").orEmpty(),
            password = optionalString(values, "voyager_navidrome_password").orEmpty(),
        )
        val jellyfin = MusicConfiguration(
            backend = MusicBackend.JELLYFIN,
            endpoint = optionalString(values, "voyager_jellyfin_endpoint").orEmpty(),
            password = optionalString(values, "voyager_jellyfin_api_key").orEmpty(),
            userId = optionalString(values, "voyager_jellyfin_user_id").orEmpty(),
        )
        val navComplete = navidrome.endpoint.isNotBlank() && navidrome.username.isNotBlank() && navidrome.password.isNotBlank()
        val jellyComplete = jellyfin.endpoint.isNotBlank() && jellyfin.password.isNotBlank() && jellyfin.userId.isNotBlank()
        val navPresent = listOf(navidrome.endpoint, navidrome.username, navidrome.password).any(String::isNotBlank)
        val jellyPresent = listOf(jellyfin.endpoint, jellyfin.password, jellyfin.userId).any(String::isNotBlank)
        if (navPresent && jellyPresent) unsupported += "music:secondary_backend"
        val selected = when {
            navComplete -> navidrome
            jellyComplete -> jellyfin
            navPresent -> navidrome.copy(backend = MusicBackend.LOCAL)
            jellyPresent -> jellyfin.copy(backend = MusicBackend.LOCAL)
            else -> MusicConfiguration()
        }
        if (selected.backend != MusicBackend.LOCAL) {
            val endpoint = ServerUrlPolicy.requireAllowed(selected.endpoint, allowLanHttp = true).toString()
            return selected.copy(endpoint = endpoint)
        }
        return selected
    }

    private fun podcastSubscriptions(raw: Any?): List<PodcastSubscription> {
        if (raw == null) return emptyList()
        require(raw is List<*> && raw.size <= MAX_PODCASTS) { "Invalid podcast subscriptions" }
        return raw.map { item ->
            require(item is Map<*, *>) { "Invalid podcast subscription" }
            val feedUrl = item["feedUrl"] as? String ?: throw IllegalArgumentException("Invalid podcast feed")
            val normalized = ServerUrlPolicy.requireAllowed(feedUrl, allowLanHttp = true).toString()
            PodcastSubscription(
                feedUrl = normalized,
                title = (item["title"] as? String)?.takeIf(String::isNotBlank) ?: normalized,
                imageUrl = item["imageUrl"] as? String,
            )
        }.distinctBy(PodcastSubscription::feedUrl)
    }

    private fun boolean(values: Map<String, Any?>, key: String, default: Boolean): Boolean {
        val value = values[key] ?: return default
        require(value is Boolean) { "Invalid boolean preference: $key" }
        return value
    }

    private fun optionalString(values: Map<String, Any?>, key: String): String? {
        val value = values[key] ?: return null
        require(value is String) { "Invalid text preference: $key" }
        return value
    }

    private const val MAX_EQUALIZER_BANDS = 32
    private const val MAX_PODCASTS = 500
    private val SUPPORTED_KEYS = setOf(
        "voyager_disclaimer_v1",
        "voyager_eq_enabled",
        "voyager_eq_gains",
        "voyager_eq_preset",
        "voyager_jellyfin_api_key",
        "voyager_jellyfin_endpoint",
        "voyager_jellyfin_user_id",
        "voyager_navidrome_endpoint",
        "voyager_navidrome_password",
        "voyager_navidrome_username",
        "voyager_night_dimming",
        "voyager_onboarding_done",
        "voyager_podcast_subscriptions",
        "voyager_remap_volume",
    )
}
