package com.voyager.voyager.feature.music

import com.voyager.voyager.core.network.ServerUrlPolicy
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONArray
import org.json.JSONObject

internal fun apiUrl(endpoint: String, path: String, query: Map<String, String> = emptyMap()): HttpUrl {
    val base = ServerUrlPolicy.requireAllowed(endpoint, allowLanHttp = true).toString().toHttpUrl()
    return base.newBuilder()
        .addPathSegments(path.trim('/'))
        .apply { query.forEach(::addQueryParameter) }
        .build()
}

internal fun JSONObject.arrayOrSingleton(name: String): JSONArray {
    val value = opt(name)
    return when (value) {
        is JSONArray -> value
        null, JSONObject.NULL -> JSONArray()
        else -> JSONArray().put(value)
    }
}

internal fun JSONObject.objects(name: String): List<JSONObject> =
    arrayOrSingleton(name).let { array ->
        buildList {
            for (index in 0 until array.length()) {
                (array.opt(index) as? JSONObject)?.let(::add)
            }
        }
    }

internal fun JSONObject.requiredSubsonic(): JSONObject {
    val response = optJSONObject("subsonic-response")
        ?: throw IllegalArgumentException("Missing Subsonic response")
    if (response.optString("status") != "ok") {
        val error = response.optJSONObject("error")
        val code = error?.optInt("code", -1) ?: -1
        val message = error?.optString("message")?.take(200).orEmpty()
        throw IllegalStateException("Subsonic error $code${if (message.isBlank()) "" else ": $message"}")
    }
    return response
}
