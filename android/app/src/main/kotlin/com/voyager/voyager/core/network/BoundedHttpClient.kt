package com.voyager.voyager.core.network

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class ResponseTooLargeException(val maxBytes: Int) : IOException("Response exceeded $maxBytes bytes")

class BoundedHttpClient(
    private val client: OkHttpClient = defaultClient(),
) {
    suspend fun getBytes(
        url: String,
        headers: Map<String, String> = emptyMap(),
        maxBytes: Int = DEFAULT_MAX_BYTES,
        allowLanHttp: Boolean = false,
    ): ByteArray = withContext(Dispatchers.IO) {
        require(maxBytes in 1..MAX_RESPONSE_BYTES) { "Invalid response budget" }
        var current = ServerUrlPolicy.requireAllowed(url, allowLanHttp)
        repeat(MAX_REDIRECTS + 1) { redirect ->
            val request = Request.Builder()
                .url(current.toString().toHttpUrl())
                .header("Accept-Encoding", "identity")
                .apply { headers.forEach(::header) }
                .build()
            val result = client.newCall(request).execute().use { response ->
                if (response.code in 300..399) {
                    val location = response.header("Location")
                        ?: throw IOException("Redirect without a destination")
                    require(redirect < MAX_REDIRECTS) { "Too many redirects" }
                    current = ServerUrlPolicy.requireAllowed(
                        current.resolve(location).toString(),
                        allowLanHttp,
                    )
                    null
                } else {
                    if (response.code != 200) throw IOException("HTTP ${response.code}")
                    val body = response.body ?: throw IOException("Empty response")
                    val declared = body.contentLength()
                    if (declared > maxBytes) throw ResponseTooLargeException(maxBytes)
                    val output = ByteArrayOutputStream(minOf(declared.toInt().coerceAtLeast(1024), maxBytes))
                    body.byteStream().use { input ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (output.size() + count > maxBytes) throw ResponseTooLargeException(maxBytes)
                            output.write(buffer, 0, count)
                        }
                    }
                    output.toByteArray()
                }
            }
            if (result != null) return@withContext result
        }
        throw IOException("Too many redirects")
    }

    suspend fun getString(
        url: String,
        headers: Map<String, String> = emptyMap(),
        maxBytes: Int = DEFAULT_MAX_BYTES,
        allowLanHttp: Boolean = false,
    ): String = getBytes(url, headers, maxBytes, allowLanHttp).toString(Charsets.UTF_8)

    suspend fun getJsonObject(
        url: String,
        headers: Map<String, String> = emptyMap(),
        maxBytes: Int = DEFAULT_MAX_BYTES,
        allowLanHttp: Boolean = false,
    ): JSONObject = JSONObject(getString(url, headers, maxBytes, allowLanHttp))

    companion object {
        const val DEFAULT_MAX_BYTES = 8 * 1024 * 1024
        const val MAX_RESPONSE_BYTES = 24 * 1024 * 1024
        private const val MAX_REDIRECTS = 4

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(8, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .callTimeout(15, TimeUnit.SECONDS)
            .followRedirects(false)
            .followSslRedirects(false)
            .build()
    }
}
