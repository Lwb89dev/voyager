package com.voyager.voyager.feature.music

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MediaStoreAudioRepository(private val context: Context) {
    fun permissionGranted(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= 33) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    suspend fun tracks(folderPrefixes: List<String> = emptyList()): List<MusicTrack> = withContext(Dispatchers.IO) {
        if (!permissionGranted()) throw SecurityException("Audio library permission is required")
        val collection = if (Build.VERSION.SDK_INT >= 29) {
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
        val prefixes = folderPrefixes.filter(String::isNotBlank)
        val selection = buildString {
            append("${MediaStore.Audio.Media.IS_MUSIC} != 0")
            if (prefixes.isNotEmpty()) {
                append(" AND (")
                append(prefixes.joinToString(" OR ") { "${MediaStore.Audio.Media.DATA} LIKE ?" })
                append(')')
            }
        }
        val arguments = prefixes.map { "$it%" }.toTypedArray()
        val result = mutableListOf<MusicTrack>()
        context.contentResolver.query(
            collection,
            projection,
            selection,
            arguments,
            "${MediaStore.Audio.Media.ALBUM} ASC, ${MediaStore.Audio.Media.TRACK} ASC, ${MediaStore.Audio.Media.TITLE} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val albumId = cursor.getLong(4)
                result += MusicTrack(
                    id = id.toString(),
                    source = MusicSource.LOCAL,
                    title = cursor.getString(1).orEmpty(),
                    artist = cleanTag(cursor.getString(2)),
                    album = cleanTag(cursor.getString(3)),
                    durationMs = cursor.getLong(5),
                    streamUrl = ContentUris.withAppendedId(collection, id).toString(),
                    artworkUrl = ContentUris.withAppendedId(ALBUM_ART, albumId).toString(),
                    trackNumber = cursor.getInt(6),
                )
            }
        }
        result
    }

    suspend fun albums(): List<MusicAlbum> = tracks().groupBy { it.album to it.artist }.map { (key, tracks) ->
        MusicAlbum(
            id = "${key.first}|${key.second}",
            source = MusicSource.LOCAL,
            name = key.first.ifBlank { "Unknown album" },
            artist = key.second,
            artworkUrl = tracks.first().artworkUrl,
        )
    }

    private fun cleanTag(value: String?): String =
        if (value == null || value == MediaStore.UNKNOWN_STRING) "" else value

    private companion object {
        val ALBUM_ART: Uri = Uri.parse("content://media/external/audio/albumart")
    }
}
