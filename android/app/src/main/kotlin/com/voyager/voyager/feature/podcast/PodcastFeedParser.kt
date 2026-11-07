package com.voyager.voyager.feature.podcast

import com.voyager.voyager.core.network.ServerUrlPolicy
import java.io.ByteArrayInputStream
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import javax.xml.XMLConstants
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Element
import org.w3c.dom.Node

class PodcastFeedParser {
    fun parse(
        bytes: ByteArray,
        fallbackTitle: String = "",
        maxEpisodes: Int = 50,
    ): PodcastFeed {
        require(maxEpisodes in 1..MAX_EPISODES) { "Invalid episode budget" }
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            isXIncludeAware = false
            isExpandEntityReferences = false
            setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            setFeature("http://xml.org/sax/features/external-general-entities", false)
            setFeature("http://xml.org/sax/features/external-parameter-entities", false)
            setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
        }
        val document = factory.newDocumentBuilder().apply {
            setEntityResolver { _, _ -> throw IllegalArgumentException("External XML entities are not allowed") }
        }.parse(ByteArrayInputStream(bytes))
        val root = document.documentElement
        return when (root.localName()) {
            "rss", "rdf" -> parseRss(root, fallbackTitle, maxEpisodes)
            "feed" -> parseAtom(root, fallbackTitle, maxEpisodes)
            else -> throw IllegalArgumentException("Unsupported podcast feed")
        }
    }

    private fun parseRss(root: Element, fallbackTitle: String, maxEpisodes: Int): PodcastFeed {
        val channel = root.children("channel").firstOrNull() ?: root
        val title = channel.childText("title").ifBlank { fallbackTitle }.ifBlank { "Podcast" }
        val image = channel.children("image").firstNotNullOfOrNull { image ->
            image.childText("url").asSafeUrl() ?: image.attribute("href").asSafeUrl()
        } ?: channel.childText("image").asSafeUrl()
        val episodes = channel.children("item").mapNotNull { item ->
            val audio = item.children("enclosure").firstNotNullOfOrNull { enclosure ->
                enclosure.attribute("url").asSafeUrl()
            } ?: item.children("content").firstNotNullOfOrNull { content ->
                content.attribute("url").asSafeUrl()
            } ?: return@mapNotNull null
            val itemTitle = item.childText("title").ifBlank { audio }
            val itemImage = item.children("image").firstNotNullOfOrNull { element ->
                element.attribute("href").asSafeUrl() ?: element.childText("url").asSafeUrl()
            } ?: image
            PodcastEpisode(
                guid = item.childText("guid").ifBlank { audio },
                title = itemTitle,
                podcastTitle = title,
                audioUrl = audio,
                durationMs = parseDuration(item.childText("duration")),
                publishedEpochMs = parseDate(item.childText("pubDate")),
                imageUrl = itemImage,
            )
        }.take(maxEpisodes)
        return PodcastFeed(title, image, episodes)
    }

    private fun parseAtom(root: Element, fallbackTitle: String, maxEpisodes: Int): PodcastFeed {
        val title = root.childText("title").ifBlank { fallbackTitle }.ifBlank { "Podcast" }
        val image = (root.childText("logo").asSafeUrl() ?: root.childText("icon").asSafeUrl())
        val episodes = root.children("entry").mapNotNull { entry ->
            val audio = entry.children("link").firstNotNullOfOrNull { link ->
                val rel = link.attribute("rel")
                val href = link.attribute("href").asSafeUrl()
                href?.takeIf { rel == "enclosure" || (rel.isBlank() && link.attribute("type").startsWith("audio/")) }
            } ?: return@mapNotNull null
            val itemImage = entry.children("image").firstNotNullOfOrNull { element ->
                element.attribute("href").asSafeUrl()
            } ?: image
            PodcastEpisode(
                guid = entry.childText("id").ifBlank { audio },
                title = entry.childText("title").ifBlank { audio },
                podcastTitle = title,
                audioUrl = audio,
                durationMs = parseDuration(entry.childText("duration")),
                publishedEpochMs = parseDate(entry.childText("published").ifBlank { entry.childText("updated") }),
                imageUrl = itemImage,
            )
        }.take(maxEpisodes)
        return PodcastFeed(title, image, episodes)
    }

    private fun String?.asSafeUrl(): String? = this?.trim()?.takeIf(String::isNotEmpty)?.let { value ->
        runCatching { ServerUrlPolicy.requireAllowed(value, allowLanHttp = true).toString() }.getOrNull()
    }

    private fun parseDuration(value: String): Long {
        val text = value.trim()
        if (text.isEmpty()) return 0
        text.toLongOrNull()?.let { return (it * 1_000).coerceAtLeast(0) }
        val parts = text.split(':')
        if (parts.size !in 2..3 || parts.any { part -> part.toLongOrNull() == null }) return 0
        val seconds = parts.fold(0L) { total, part -> total * 60 + part.toLong() }
        return (seconds * 1_000).coerceAtLeast(0)
    }

    private fun parseDate(value: String): Long? {
        val text = value.trim()
        if (text.isEmpty()) return null
        return runCatching { Instant.parse(text).toEpochMilli() }.getOrElse {
            runCatching {
                ZonedDateTime.parse(text, DateTimeFormatter.RFC_1123_DATE_TIME.withLocale(Locale.US))
                    .toInstant().toEpochMilli()
            }.getOrNull()
        }
    }

    private fun Element.localName(): String = localName ?: nodeName.substringAfter(':').lowercase(Locale.ROOT)

    private fun Element.children(name: String): List<Element> {
        val result = mutableListOf<Element>()
        var node = firstChild
        while (node != null) {
            if (node.nodeType == Node.ELEMENT_NODE && (node as Element).localName() == name) result += node
            node = node.nextSibling
        }
        return result
    }

    private fun Element.childText(name: String): String =
        children(name).firstOrNull()?.textContent?.trim().orEmpty()

    private fun Element.attribute(name: String): String =
        if (hasAttribute(name)) getAttribute(name).trim() else ""

    companion object {
        const val MAX_EPISODES = 200
    }
}
