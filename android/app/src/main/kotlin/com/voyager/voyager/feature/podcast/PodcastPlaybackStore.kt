package com.voyager.voyager.feature.podcast

import android.content.Context
import org.json.JSONObject

private const val COMPLETION_REMAINING_MS = 10_000L

data class PodcastPlaybackPosition(
    val positionMs: Long,
    val durationMs: Long,
    val updatedAtEpochMs: Long,
) {
    fun resumePositionMs(): Long = when {
        positionMs <= 0 -> 0
        durationMs > 0 && positionMs >= durationMs - COMPLETION_REMAINING_MS -> 0
        durationMs > 0 -> positionMs.coerceAtMost(durationMs)
        else -> positionMs
    }
}

interface PodcastPlaybackStore {
    fun load(episodeId: String): PodcastPlaybackPosition?
    fun save(episodeId: String, position: PodcastPlaybackPosition)
}

class SharedPreferencesPodcastPlaybackStore(
    context: Context,
    private val now: () -> Long = System::currentTimeMillis,
) : PodcastPlaybackStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_podcasts",
        Context.MODE_PRIVATE,
    )

    @Synchronized
    override fun load(episodeId: String): PodcastPlaybackPosition? {
        val item = all().optJSONObject(episodeId) ?: return null
        return PodcastPlaybackPosition(
            positionMs = item.optLong("positionMs").coerceAtLeast(0),
            durationMs = item.optLong("durationMs").coerceAtLeast(0),
            updatedAtEpochMs = item.optLong("updatedAtEpochMs").coerceAtLeast(0),
        )
    }

    @Synchronized
    override fun save(episodeId: String, position: PodcastPlaybackPosition) {
        val positions = all()
        positions.put(
            episodeId,
            JSONObject()
                .put("positionMs", position.positionMs.coerceAtLeast(0))
                .put("durationMs", position.durationMs.coerceAtLeast(0))
                .put("updatedAtEpochMs", now()),
        )
        val keys = positions.keys().asSequence().toList()
        if (keys.size > MAX_POSITIONS) {
            keys.sortedBy { key -> positions.optJSONObject(key)?.optLong("updatedAtEpochMs") ?: 0 }
                .take(keys.size - MAX_POSITIONS)
                .forEach { positions.remove(it) }
        }
        check(preferences.edit().putString(KEY_POSITIONS, positions.toString()).commit()) {
            "Podcast playback position could not be saved"
        }
    }

    private fun all(): JSONObject = preferences.getString(KEY_POSITIONS, null)
        ?.let(::JSONObject)
        ?: JSONObject()

    companion object {
        private const val KEY_POSITIONS = "playback_positions_v1"
        private const val MAX_POSITIONS = 500
    }
}
