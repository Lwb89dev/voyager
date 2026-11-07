package com.voyager.voyager.feature.music

import java.security.MessageDigest
import java.security.SecureRandom

internal class SubsonicApi(
    private val endpoint: String,
    private val username: String,
    private val password: String,
) {
    private val random = SecureRandom()

    fun uri(method: String, parameters: Map<String, String> = emptyMap()): String {
        val salt = ByteArray(16).also(random::nextBytes).joinToString("") { "%02x".format(it) }
        val token = md5(password + salt)
        return apiUrl(
            endpoint = endpoint,
            path = "rest/$method",
            query = parameters + mapOf(
                "u" to username,
                "t" to token,
                "s" to salt,
                "v" to "1.16.1",
                "c" to "voyager",
                "f" to "json",
            ),
        ).toString()
    }

    private fun md5(value: String): String = MessageDigest.getInstance("MD5")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
