package com.voyager.voyager.legacy.migration

import android.content.Context
import java.io.File
import java.util.Base64

class AndroidVoyagerLegacyReader(
    context: Context,
    private val hiveReader: LegacyHiveReader = LegacyHiveReader(),
) : VoyagerLegacyReader {
    private val applicationContext = context.applicationContext
    private val secureReader = FlutterSecureStorageReader(applicationContext)

    override fun read(): VoyagerLegacySnapshot? {
        val file = File(applicationContext.applicationInfo.dataDir, HIVE_PATH)
        if (!file.isFile) return null
        val encodedKey = secureReader.read(setOf(HIVE_KEY_NAME))[HIVE_KEY_NAME]
            ?: throw IllegalStateException("Legacy Hive key is unavailable")
        val key = Base64.getDecoder().decode(encodedKey)
        return VoyagerLegacySnapshotMapper.map(hiveReader.read(file, key))
    }

    private companion object {
        const val HIVE_PATH = "app_flutter/settings.hive"
        const val HIVE_KEY_NAME = "hive_settings_key"
    }
}
