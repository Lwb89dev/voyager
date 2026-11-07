package com.voyager.voyager.legacy.migration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class LegacyHiveReaderTest {
    private val reader = LegacyHiveReader()
    private val key = ByteArray(32) { it.toByte() }

    @Test
    fun readsAnEncryptedBoxProducedByRealHive() {
        val values = reader.read(fixture(), key)

        assertEquals(false, values["voyager_night_dimming"])
        assertEquals(true, values["voyager_remap_volume"])
        assertEquals(listOf(1.5, -2.0, 0.25, 0.0, 3.0), values["voyager_eq_gains"])
        assertEquals("driver", values["voyager_navidrome_username"])
        assertEquals(false, values["imperialUnits"])
        assertEquals(
            listOf("/storage/emulated/0/Music"),
            values["voyager_music_folders"],
        )
        val subscriptions = values["voyager_podcast_subscriptions"] as List<*>
        val first = subscriptions.single() as Map<*, *>
        assertEquals("Fixture show", first["title"])
        assertTrue(first.containsKey("imageUrl"))
        assertEquals(null, first["imageUrl"])
    }

    @Test
    fun lastWriteWinsAndDeletedFramesRemoveOlderValues() {
        val values = reader.read(fixture(), key)

        assertEquals("second", values["overwritten"])
        assertFalse(values.containsKey("deleted"))
    }

    @Test
    fun wrongKeyFailsClosed() {
        val wrongKey = ByteArray(32) { 1 }

        assertThrows(IllegalArgumentException::class.java) {
            reader.read(fixture(), wrongKey)
        }
    }

    @Test
    fun modifiedFrameFailsItsChecksum() {
        val corrupted = fixture()
        corrupted[100] = (corrupted[100].toInt() xor 1).toByte()

        assertThrows(IllegalArgumentException::class.java) {
            reader.read(corrupted, key)
        }
    }

    private fun fixture(): ByteArray = requireNotNull(
        javaClass.getResourceAsStream("/legacy/settings.hive"),
    ).use { it.readBytes() }
}
