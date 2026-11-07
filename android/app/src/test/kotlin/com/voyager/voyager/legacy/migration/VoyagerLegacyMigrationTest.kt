package com.voyager.voyager.legacy.migration

import com.voyager.voyager.feature.music.EqualizerSettings
import com.voyager.voyager.feature.music.MusicConfiguration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoyagerLegacyMigrationTest {
    private val snapshot = VoyagerLegacySnapshot(
        music = MusicConfiguration(),
        podcasts = emptyList(),
        equalizer = EqualizerSettings(),
        nightDimming = true,
        remapVolume = false,
        onboardingCompleted = true,
        unsupportedData = setOf("music:voyager_music_folders"),
    )

    @Test
    fun successfulRunVerifiesBeforeWritingTheMarkerAndIsIdempotent() {
        val target = FakeTarget()
        val marker = FakeMarker()
        val migration = VoyagerLegacyMigration({ snapshot }, target, marker)

        assertEquals(VoyagerLegacyMigrationOutcome.Migrated, migration.run().outcome)
        assertEquals(listOf("stage", "commit", "verify"), target.calls)
        assertTrue(marker.complete)
        assertEquals(snapshot.unsupportedData, marker.unsupported)
        assertEquals(VoyagerLegacyMigrationOutcome.AlreadyComplete, migration.run().outcome)
        assertEquals(1, target.commits)
    }

    @Test
    fun failedCommitLeavesMarkerUnsetAndCanBeRetried() {
        val target = FakeTarget(failCommitOnce = true)
        val marker = FakeMarker()
        val migration = VoyagerLegacyMigration({ snapshot }, target, marker)

        assertEquals(VoyagerLegacyMigrationOutcome.Failed, migration.run().outcome)
        assertFalse(marker.complete)
        assertEquals(VoyagerLegacyMigrationOutcome.Migrated, migration.run().outcome)
        assertTrue(marker.complete)
        assertEquals(2, target.commits)
    }

    @Test
    fun failedVerificationDoesNotMarkMigrationComplete() {
        val target = FakeTarget(failVerify = true)
        val marker = FakeMarker()

        val result = VoyagerLegacyMigration({ snapshot }, target, marker).run()

        assertEquals(VoyagerLegacyMigrationOutcome.Failed, result.outcome)
        assertFalse(marker.complete)
    }

    @Test
    fun missingLegacyDataCompletesWithoutWritingTarget() {
        val target = FakeTarget()
        val marker = FakeMarker()

        val result = VoyagerLegacyMigration({ null }, target, marker).run()

        assertEquals(VoyagerLegacyMigrationOutcome.NotNeeded, result.outcome)
        assertTrue(marker.complete)
        assertEquals(0, target.commits)
    }

    private class FakeTarget(
        private val failCommitOnce: Boolean = false,
        private val failVerify: Boolean = false,
    ) : VoyagerLegacyTarget {
        val calls = mutableListOf<String>()
        var commits = 0
        override fun stage(snapshot: VoyagerLegacySnapshot) {
            calls += "stage"
        }
        override fun commit() {
            calls += "commit"
            commits++
            if (failCommitOnce && commits == 1) error("commit failed")
        }
        override fun verify(snapshot: VoyagerLegacySnapshot) {
            calls += "verify"
            if (failVerify) error("verify failed")
        }
    }

    private class FakeMarker : VoyagerLegacyMigrationMarker {
        var complete = false
        var unsupported = emptySet<String>()
        override fun isComplete(): Boolean = complete
        override fun markComplete(unsupportedData: Set<String>) {
            unsupported = unsupportedData
            complete = true
        }
    }
}
