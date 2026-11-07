package com.voyager.voyager.core.network

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class BoundedHttpClientTest {
    @Test
    fun readsJsonWithinBudget() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("""{"ok":true}"""))
        server.start()
        val client = BoundedHttpClient()
        val result = client.getJsonObject(server.url("/").toString(), allowLanHttp = true)
        assertTrue(result.getBoolean("ok"))
        server.shutdown()
    }

    @Test
    fun abortsDeclaredAndStreamingOversizeResponses() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("12345"))
        server.start()
        val client = BoundedHttpClient()
        try {
            client.getBytes(server.url("/").toString(), maxBytes = 4, allowLanHttp = true)
            fail("Expected response cap")
        } catch (error: ResponseTooLargeException) {
            assertEquals(4, error.maxBytes)
        }
        server.shutdown()
    }

    @Test
    fun validatesEveryRedirect() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setResponseCode(302).addHeader("Location", "http://example.com/"))
        server.start()
        val client = BoundedHttpClient()
        try {
            client.getBytes(server.url("/").toString(), allowLanHttp = true)
            fail("Expected public cleartext redirect to be rejected")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("private LAN"))
        }
        server.shutdown()
    }

    @Test
    fun publicCleartextAndPrivateAddressRulesAreExplicit() {
        try {
            ServerUrlPolicy.requireAllowed("http://example.com", allowLanHttp = true)
            fail("Expected HTTPS requirement")
        } catch (_: IllegalArgumentException) {
        }
        assertTrue(ServerUrlPolicy.isPrivateHost("127.0.0.1"))
        assertTrue(ServerUrlPolicy.isPrivateHost("192.168.1.10"))
        assertFalse(ServerUrlPolicy.isPrivateHost("0.0.0.0"))
    }

    @Test
    fun rejectsNonObjectJson() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("[]"))
        server.start()
        try {
            BoundedHttpClient().getJsonObject(server.url("/").toString(), allowLanHttp = true)
            fail("Expected JSON object requirement")
        } catch (_: Exception) {
        }
        server.shutdown()
    }
}
