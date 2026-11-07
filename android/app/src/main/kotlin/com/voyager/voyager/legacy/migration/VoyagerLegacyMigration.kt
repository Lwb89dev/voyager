package com.voyager.voyager.legacy.migration

import android.content.Context
import app.roadstr.roadtest.NativeLiveStoreNames
import com.voyager.voyager.feature.music.EqualizerBridge
import com.voyager.voyager.feature.music.EqualizerSettingsStore
import com.voyager.voyager.feature.music.MusicConfigurationStore
import com.voyager.voyager.feature.podcast.PodcastSubscriptionStore
import com.voyager.voyager.feature.podcast.SharedPreferencesPodcastSubscriptionStore

fun interface VoyagerLegacyReader {
    fun read(): VoyagerLegacySnapshot?
}

interface VoyagerLegacyTarget {
    fun stage(snapshot: VoyagerLegacySnapshot)
    fun commit()
    fun verify(snapshot: VoyagerLegacySnapshot)
}

interface VoyagerLegacyMigrationMarker {
    fun isComplete(): Boolean
    fun markComplete(unsupportedData: Set<String>)
}

enum class VoyagerLegacyMigrationOutcome { AlreadyComplete, NotNeeded, Migrated, Failed }

data class VoyagerLegacyMigrationResult(
    val outcome: VoyagerLegacyMigrationOutcome,
    val unsupportedData: Set<String> = emptySet(),
)

class VoyagerLegacyMigration(
    private val reader: VoyagerLegacyReader,
    private val target: VoyagerLegacyTarget,
    private val marker: VoyagerLegacyMigrationMarker,
) {
    fun run(): VoyagerLegacyMigrationResult {
        try {
            if (marker.isComplete()) return VoyagerLegacyMigrationResult(VoyagerLegacyMigrationOutcome.AlreadyComplete)
            val snapshot = try {
                reader.read()
            } catch (_: Exception) {
                return VoyagerLegacyMigrationResult(VoyagerLegacyMigrationOutcome.Failed)
            } ?: run {
                marker.markComplete(emptySet())
                return VoyagerLegacyMigrationResult(VoyagerLegacyMigrationOutcome.NotNeeded)
            }
            target.stage(snapshot)
            target.commit()
            target.verify(snapshot)
            marker.markComplete(snapshot.unsupportedData)
            return VoyagerLegacyMigrationResult(VoyagerLegacyMigrationOutcome.Migrated, snapshot.unsupportedData)
        } catch (_: Exception) {
            return VoyagerLegacyMigrationResult(VoyagerLegacyMigrationOutcome.Failed)
        }
    }
}

class AndroidVoyagerLegacyTarget(
    context: Context,
    names: NativeLiveStoreNames,
) : VoyagerLegacyTarget {
    private val music = MusicConfigurationStore(context)
    private val podcasts: PodcastSubscriptionStore = SharedPreferencesPodcastSubscriptionStore(context)
    private val equalizer = EqualizerSettingsStore(context)
    private val automotive = context.applicationContext.getSharedPreferences("voyager_automotive", Context.MODE_PRIVATE)
    private val onboarding = context.applicationContext.getSharedPreferences(names.prefs("onboarding"), Context.MODE_PRIVATE)
    private var staged: VoyagerLegacySnapshot? = null

    override fun stage(snapshot: VoyagerLegacySnapshot) {
        staged = snapshot
    }

    override fun commit() {
        val snapshot = requireNotNull(staged) { "No staged Voyager migration" }
        music.save(snapshot.music)
        podcasts.save(snapshot.podcasts)
        equalizer.save(snapshot.equalizer)
        check(
            automotive.edit()
                .putBoolean(KEY_NIGHT_DIMMING, snapshot.nightDimming)
                .putBoolean(KEY_REMAP_VOLUME, snapshot.remapVolume)
                .commit(),
        ) { "Automotive preferences could not be migrated" }
        check(onboarding.edit().putBoolean(KEY_ONBOARDING_COMPLETE, snapshot.onboardingCompleted).commit()) {
            "Onboarding state could not be migrated"
        }
        EqualizerBridge.update(snapshot.equalizer)
    }

    override fun verify(snapshot: VoyagerLegacySnapshot) {
        check(music.load() == snapshot.music) { "Music migration verification failed" }
        check(podcasts.load() == snapshot.podcasts) { "Podcast migration verification failed" }
        check(equalizer.load() == snapshot.equalizer) { "Equalizer migration verification failed" }
        check(automotive.getBoolean(KEY_NIGHT_DIMMING, !snapshot.nightDimming) == snapshot.nightDimming) {
            "Night-dimming migration verification failed"
        }
        check(automotive.getBoolean(KEY_REMAP_VOLUME, !snapshot.remapVolume) == snapshot.remapVolume) {
            "Key-remap migration verification failed"
        }
        check(onboarding.getBoolean(KEY_ONBOARDING_COMPLETE, !snapshot.onboardingCompleted) == snapshot.onboardingCompleted) {
            "Onboarding migration verification failed"
        }
    }

    private companion object {
        const val KEY_NIGHT_DIMMING = "night_dimming"
        const val KEY_REMAP_VOLUME = "remap_volume_keys"
        const val KEY_ONBOARDING_COMPLETE = "completed"
    }
}

class SharedPreferencesVoyagerLegacyMigrationMarker(context: Context) : VoyagerLegacyMigrationMarker {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_native_migration",
        Context.MODE_PRIVATE,
    )

    override fun isComplete(): Boolean = preferences.getBoolean(KEY_COMPLETE, false)

    override fun markComplete(unsupportedData: Set<String>) {
        check(
            preferences.edit()
                .putStringSet(KEY_UNSUPPORTED, unsupportedData)
                .putBoolean(KEY_COMPLETE, true)
                .commit(),
        ) { "Migration completion could not be recorded" }
    }

    private companion object {
        const val KEY_COMPLETE = "voyager_v1_complete"
        const val KEY_UNSUPPORTED = "voyager_v1_unsupported"
    }
}
