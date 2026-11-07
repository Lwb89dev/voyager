package com.voyager.voyager.core.network

import java.net.InetAddress
import java.net.URI

object ServerUrlPolicy {
    fun requireAllowed(url: String, allowLanHttp: Boolean = false): URI {
        val uri = URI(url).normalize()
        require(uri.scheme == "https" || uri.scheme == "http") { "Only HTTP(S) URLs are supported" }
        require(uri.host != null && uri.userInfo == null) { "Invalid server URL" }
        require(uri.fragment == null) { "URL fragments are not supported" }
        if (uri.scheme == "http") {
            require(allowLanHttp) { "HTTPS is required" }
            require(isPrivateHost(uri.host)) { "Cleartext is limited to private LAN servers" }
        }
        return uri
    }

    fun isPrivateHost(host: String): Boolean = try {
        val addresses = InetAddress.getAllByName(host)
        addresses.isNotEmpty() && addresses.all(::isPrivateAddress)
    } catch (_: Exception) {
        false
    }

    private fun isPrivateAddress(address: InetAddress): Boolean {
        val bytes = address.address
        if (address.isLoopbackAddress || address.isLinkLocalAddress) return true
        if (address.isAnyLocalAddress || address.isMulticastAddress) return false
        return when (bytes.size) {
            4 -> {
                val a = bytes[0].toInt() and 0xff
                val b = bytes[1].toInt() and 0xff
                a == 10 || (a == 172 && b in 16..31) || (a == 192 && b == 168)
            }
            16 -> {
                val first = bytes[0].toInt() and 0xff
                val second = bytes[1].toInt() and 0xff
                (first and 0xfe) == 0xfc || (first == 0xfe && (second and 0xc0) == 0x80)
            }
            else -> false
        }
    }
}
