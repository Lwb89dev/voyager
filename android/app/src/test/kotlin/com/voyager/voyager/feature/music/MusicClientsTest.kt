package com.voyager.voyager.feature.music

import com.voyager.voyager.core.network.BoundedHttpClient
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private fun subsonic(body: String): String = """{"subsonic-response":{"status":"ok",$body}}"""

class MusicClientsTest {
    @Test
    fun subsonicUsesSaltedTokenAndParsesAlbum() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody(subsonic(""""ping":{}""")))
        server.enqueue(MockResponse().setBody(subsonic(""""randomSongs":{"song":[{"id":"t1","title":"Track","artist":"Artist","duration":123}]}""")))
        server.start()
        val client = NavidromeClient(server.url("/").toString(), "user", "secret")
        client.ping()
        val tracks = client.randomTracks()

        val auth = server.takeRequest().requestUrl!!
        assertEquals("user", auth.queryParameter("u"))
        assertEquals(32, auth.queryParameter("t")!!.length)
        assertEquals(32, auth.queryParameter("s")!!.length)
        assertFalse(auth.queryParameterNames.contains("p"))
        assertEquals(123_000, tracks.single().durationMs)
        assertNotEquals(client.streamUrl("t1"), client.streamUrl("t1"))
        server.shutdown()
    }

    @Test
    fun subsonicSingleObjectAndErrorAreHandled() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody(subsonic(""""albumList2":{"album":{"id":"a","name":"Album"}}""")))
        server.enqueue(MockResponse().setBody("""{"subsonic-response":{"status":"failed","error":{"code":40,"message":"Wrong credentials"}}}"""))
        server.start()
        val client = NavidromeClient(server.url("/").toString(), "user", "secret")
        assertEquals("Album", client.recentAlbums().single().name)
        try {
            client.ping()
            throw AssertionError("Expected server error")
        } catch (error: IllegalStateException) {
            assertTrue(error.message!!.contains("40"))
        }
        server.shutdown()
    }

    @Test
    fun jellyfinUsesHeaderAndConvertsTicks() = runTest {
        val server = MockWebServer()
        server.enqueue(MockResponse().setBody("""{"Items":[{"Id":"t","Name":"Song","Artists":["Artist"],"RunTimeTicks":12345000000}]}"""))
        server.start()
        val client = JellyfinClient(server.url("/").toString(), "key", "user")
        val track = client.randomTracks().single()

        val request = server.takeRequest()
        assertEquals("key", request.getHeader("X-Emby-Token"))
        assertEquals(1_234_500, track.durationMs)
        assertEquals("Artist", track.artist)
        assertEquals("key", track.requestHeaders["X-Emby-Token"])
        assertFalse(client.streamUrl("t").contains("api_key"))
        server.shutdown()
    }
}
