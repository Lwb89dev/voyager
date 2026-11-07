package com.voyager.voyager.legacy.migration

import com.voyager.voyager.feature.music.EqualizerPreset
import com.voyager.voyager.feature.music.MusicBackend
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VoyagerLegacySnapshotMapperTest {
    @Test
    fun mapsRealVoyagerFixtureIntoNativeStores() {
        val values = LegacyHiveReader().read(fixture(), ByteArray(32) { it.toByte() })

        val snapshot = VoyagerLegacySnapshotMapper.map(values)

        assertEquals(MusicBackend.NAVIDROME, snapshot.music.backend)
        assertEquals("http://192.168.1.20:4533", snapshot.music.endpoint)
        assertEquals("driver", snapshot.music.username)
        assertEquals("not-a-real-password", snapshot.music.password)
        assertEquals("Fixture show", snapshot.podcasts.single().title)
        assertEquals(true, snapshot.equalizer.enabled)
        assertEquals(EqualizerPreset.CUSTOM, snapshot.equalizer.preset)
        assertEquals(listOf(1.5, -2.0, 0.25, 0.0, 3.0), snapshot.equalizer.gains)
        assertEquals(false, snapshot.nightDimming)
        assertEquals(true, snapshot.remapVolume)
        assertEquals(true, snapshot.onboardingCompleted)
        assertTrue("hive:voyager_music_folders" in snapshot.unsupportedData)
        assertTrue("roadstr:profile_pending" in snapshot.unsupportedData)
    }

    @Test
    fun secondConfiguredBackendIsReportedInsteadOfBeingSilentlyDropped() {
        val snapshot = VoyagerLegacySnapshotMapper.map(
            mapOf(
                "voyager_navidrome_endpoint" to "https://nav.example.com",
                "voyager_navidrome_username" to "user",
                "voyager_navidrome_password" to "secret",
                "voyager_jellyfin_endpoint" to "https://jelly.example.com",
                "voyager_jellyfin_api_key" to "key",
                "voyager_jellyfin_user_id" to "id",
            ),
        )

        assertEquals(MusicBackend.NAVIDROME, snapshot.music.backend)
        assertTrue("music:secondary_backend" in snapshot.unsupportedData)
    }

    private fun fixture(): ByteArray = requireNotNull(
        javaClass.getResourceAsStream("/legacy/settings.hive"),
    ).use { it.readBytes() }
}
