package com.voyager.voyager

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Indexes the device's music through MediaStore.
 *
 * This replaces walking directories from Dart, which was wrong in two ways.
 * It looked in the app's private media folder — empty for everyone who has not
 * copied files there by hand — and even pointed at the shared volume it would
 * have had to open and parse thousands of files to learn anything beyond their
 * filenames.
 *
 * MediaStore is the index Android already maintains: every audio file on the
 * device, with the tags already parsed, updated by the system as files come and
 * go. One query returns in milliseconds what a filesystem walk takes seconds to
 * approximate. It is also the only approach that is correct under scoped
 * storage, where an app has no general right to read the shared volume but does
 * have the right to read audio it has been granted access to.
 *
 * This is the same shape as Auxio's indexing, which is where the idea comes
 * from. Auxio itself could not be reused — it is a standalone Kotlin app rather
 * than a library — but the approach transfers.
 *
 * Playback URIs are `content://` rather than file paths, so ExoPlayer opens
 * them through the resolver and no direct filesystem access is needed at all.
 */
class MediaStoreBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "queryAudio" -> queryAudio(call, result)
            else -> result.notImplemented()
        }
    }

    private fun queryAudio(call: MethodCall, result: MethodChannel.Result) {
        // An optional subtree filter, set when the user picked one or more
        // folders. Without it the whole library is indexed, which is what most
        // people want and what makes the folder picker optional rather than a
        // setup step.
        val pathPrefixes = call.argument<List<String>>("pathPrefixes")

        try {
            result.success(collect(pathPrefixes))
        } catch (error: SecurityException) {
            // The audio permission was refused or revoked while running. Report
            // it as such rather than as an empty library: they need different
            // things from the user.
            result.error("permission_denied", error.message, null)
        } catch (error: Exception) {
            result.error("query_failed", error.message, null)
        }
    }

    private fun collect(pathPrefixes: List<String>?): List<Map<String, Any?>> {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DATA,
        )

        // IS_MUSIC excludes ringtones, notification sounds and alarms, which are
        // audio files on the same volume and are not what anyone means by "my
        // music". Voice recordings and podcasts are left in: they are things
        // people deliberately put on a device to listen to on a drive.
        val selection = StringBuilder("${MediaStore.Audio.Media.IS_MUSIC} != 0")
        val arguments = mutableListOf<String>()
        val prefixes = pathPrefixes?.filter { it.isNotBlank() } ?: emptyList()
        if (prefixes.isNotEmpty()) {
            // Any one of the chosen folders — an OR'd group of LIKE clauses,
            // parenthesised so it combines correctly with the IS_MUSIC term
            // ahead of it rather than short-circuiting the whole selection.
            val clause = prefixes.joinToString(" OR ") {
                "${MediaStore.Audio.Media.DATA} LIKE ?"
            }
            selection.append(" AND ($clause)")
            arguments.addAll(prefixes.map { "$it%" })
        }

        val order = "${MediaStore.Audio.Media.ALBUM} ASC, " +
            "${MediaStore.Audio.Media.TRACK} ASC, " +
            "${MediaStore.Audio.Media.TITLE} ASC"

        val tracks = mutableListOf<Map<String, Any?>>()
        resolver().query(
            collection,
            projection,
            selection.toString(),
            arguments.toTypedArray(),
            order,
        )?.use { cursor -> readAll(cursor, collection, tracks) }
        return tracks
    }

    private fun readAll(
        cursor: Cursor,
        collection: Uri,
        into: MutableList<Map<String, Any?>>,
    ) {
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
        val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
        val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
        val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
        val albumIdColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
        val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
        val trackColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)

        while (cursor.moveToNext()) {
            val id = cursor.getLong(idColumn)
            val albumId = cursor.getLong(albumIdColumn)
            into.add(
                mapOf(
                    "id" to id.toString(),
                    "title" to cursor.getString(titleColumn).orEmpty(),
                    // MediaStore writes the literal string "<unknown>" for a
                    // missing tag. Passing that straight through would put it
                    // on screen, so it becomes an empty string and the UI
                    // decides what to show instead.
                    "artist" to cleanTag(cursor.getString(artistColumn)),
                    "album" to cleanTag(cursor.getString(albumColumn)),
                    "albumId" to albumId.toString(),
                    "durationMs" to cursor.getLong(durationColumn),
                    "track" to cursor.getInt(trackColumn),
                    "uri" to ContentUris.withAppendedId(collection, id).toString(),
                    "artUri" to albumArtUri(albumId).toString(),
                ),
            )
        }
    }

    /**
     * The album-art URI.
     *
     * `content://media/external/audio/albumart/<id>` is technically a legacy
     * path, but it is still resolvable on current Android and is the only form
     * that can be handed to another component as a plain URI. The modern
     * replacement, `ContentResolver.loadThumbnail`, returns a Bitmap and would
     * mean shuttling image bytes over the method channel for every track.
     */
    private fun albumArtUri(albumId: Long): Uri =
        ContentUris.withAppendedId(
            Uri.parse("content://media/external/audio/albumart"),
            albumId,
        )

    private fun cleanTag(value: String?): String =
        if (value == null || value == MediaStore.UNKNOWN_STRING) "" else value

    private fun resolver(): ContentResolver = context.contentResolver

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL = "com.voyager.voyager/media_store"
    }
}
