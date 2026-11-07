package com.voyager.voyager.feature.music

import android.content.Context
import com.voyager.voyager.core.storage.KeystoreTextStore
import org.json.JSONObject

enum class MusicBackend { LOCAL, NAVIDROME, JELLYFIN }

data class MusicConfiguration(
    val backend: MusicBackend = MusicBackend.LOCAL,
    val endpoint: String = "",
    val username: String = "",
    val password: String = "",
    val userId: String = "",
)

class MusicConfigurationStore(context: Context) {
    private val store = KeystoreTextStore(context, "voyager-music-v1", "com.voyager.voyager.music.v1")

    fun load(): MusicConfiguration {
        val raw = store.read() ?: return MusicConfiguration()
        val json = JSONObject(raw)
        return MusicConfiguration(
            backend = MusicBackend.valueOf(json.optString("backend", MusicBackend.LOCAL.name)),
            endpoint = json.optString("endpoint"),
            username = json.optString("username"),
            password = json.optString("password"),
            userId = json.optString("userId"),
        )
    }

    fun save(configuration: MusicConfiguration) {
        store.write(
            JSONObject()
                .put("backend", configuration.backend.name)
                .put("endpoint", configuration.endpoint)
                .put("username", configuration.username)
                .put("password", configuration.password)
                .put("userId", configuration.userId)
                .toString(),
        )
    }
}
