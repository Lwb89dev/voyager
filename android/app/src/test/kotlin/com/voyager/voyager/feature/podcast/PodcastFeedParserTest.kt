package com.voyager.voyager.feature.podcast

import com.voyager.voyager.feature.music.MusicSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PodcastFeedParserTest {
    private val parser = PodcastFeedParser()

    @Test
    fun rssFeedParsesPlayableEpisodesAndSkipsTextPosts() {
        val feed = parser.parse(
            """
            <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
              <channel>
                <title>Example show</title>
                <itunes:image href="https://example.com/show.jpg" />
                <item>
                  <guid>episode-1</guid>
                  <title>First episode</title>
                  <enclosure url="https://cdn.example.com/one.mp3" type="audio/mpeg" />
                  <itunes:duration>01:02:03</itunes:duration>
                  <pubDate>Tue, 27 Oct 2026 10:30:00 GMT</pubDate>
                </item>
                <item><title>Text announcement</title></item>
                <item>
                  <title>Second episode</title>
                  <enclosure url="https://cdn.example.com/two.mp3" />
                  <itunes:duration>95</itunes:duration>
                </item>
              </channel>
            </rss>
            """.trimIndent().toByteArray(),
        )

        assertEquals("Example show", feed.title)
        assertEquals("https://example.com/show.jpg", feed.imageUrl)
        assertEquals(2, feed.episodes.size)
        val episode = feed.episodes.first()
        assertEquals(3_723_000, episode.durationMs)
        assertEquals(1793097000000, episode.publishedEpochMs)
        assertEquals(MusicSource.PODCAST, episode.toTrack().source)
        assertEquals("https://cdn.example.com/two.mp3", feed.episodes[1].guid)
        assertEquals(95_000, feed.episodes[1].durationMs)
    }

    @Test
    fun atomFeedParsesEnclosuresAndIsoDates() {
        val feed = parser.parse(
            """
            <feed xmlns="http://www.w3.org/2005/Atom">
              <title>Atom show</title>
              <logo>https://example.com/atom.png</logo>
              <entry>
                <id>tag:example.com,2026:1</id>
                <title>Atom episode</title>
                <link rel="alternate" href="https://example.com/read" />
                <link rel="enclosure" href="https://example.com/listen.mp3" type="audio/mpeg" />
                <updated>2026-10-27T12:00:00Z</updated>
              </entry>
            </feed>
            """.trimIndent().toByteArray(),
        )

        assertEquals("Atom show", feed.title)
        assertEquals("tag:example.com,2026:1", feed.episodes.single().guid)
        assertEquals(1793102400000, feed.episodes.single().publishedEpochMs)
        assertEquals("https://example.com/listen.mp3", feed.episodes.single().audioUrl)
    }

    @Test
    fun doctypeAndExternalEntitiesAreRejected() {
        val xml = """
            <!DOCTYPE rss [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
            <rss><channel><title>&xxe;</title></channel></rss>
        """.trimIndent()

        val error = runCatching { parser.parse(xml.toByteArray()) }.exceptionOrNull()
        assertTrue(error is org.xml.sax.SAXException)
    }

    @Test
    fun insecurePublicAudioAndInvalidMetadataAreHandledConservatively() {
        val feed = parser.parse(
            """
            <rss><channel><title>Show</title><item>
              <title>Episode</title>
              <enclosure url="http://public.example.com/episode.mp3" />
              <itunes:duration xmlns:itunes="urn:test">not-a-duration</itunes:duration>
              <pubDate>not-a-date</pubDate>
            </item></channel></rss>
            """.trimIndent().toByteArray(),
        )
        assertTrue(feed.episodes.isEmpty())

        val valid = parser.parse(
            """
            <rss><channel><title>Show</title><item>
              <enclosure url="https://example.com/episode.mp3" />
              <itunes:duration xmlns:itunes="urn:test">bad</itunes:duration>
              <pubDate>bad</pubDate>
            </item></channel></rss>
            """.trimIndent().toByteArray(),
        ).episodes.single()
        assertEquals(0, valid.durationMs)
        assertNull(valid.publishedEpochMs)
    }

    @Test
    fun episodeLimitAppliesAfterTextPostsAreSkipped() {
        val feed = parser.parse(
            """
            <rss><channel><title>Show</title>
              <item><title>Text</title></item>
              <item><enclosure url="https://example.com/1.mp3" /></item>
              <item><enclosure url="https://example.com/2.mp3" /></item>
            </channel></rss>
            """.trimIndent().toByteArray(),
            maxEpisodes = 1,
        )
        assertEquals(listOf("https://example.com/1.mp3"), feed.episodes.map { it.audioUrl })
    }
}
