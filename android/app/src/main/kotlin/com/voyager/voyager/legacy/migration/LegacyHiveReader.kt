package com.voyager.voyager.legacy.migration

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.CodingErrorAction
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

class LegacyHiveReader(private val maxBoxBytes: Long = MAX_BOX_BYTES) {
    fun read(file: File, key: ByteArray): Map<String, Any?> {
        require(key.size == KEY_BYTES) { "Invalid Hive key" }
        require(file.isFile && file.length() in 0..maxBoxBytes) { "Invalid Hive box size" }
        return read(file.readBytes(), key)
    }

    fun read(bytes: ByteArray, key: ByteArray): Map<String, Any?> {
        require(key.size == KEY_BYTES) { "Invalid Hive key" }
        require(bytes.size <= maxBoxBytes) { "Hive box is too large" }
        val values = linkedMapOf<String, Any?>()
        val keyCrc = crc32(MessageDigest.getInstance("SHA-256").digest(key))
        var offset = 0
        while (offset < bytes.size) {
            require(bytes.size - offset >= MIN_FRAME_BYTES) { "Truncated Hive frame" }
            val frameLength = littleEndianUInt(bytes, offset).toInt()
            require(frameLength >= MIN_FRAME_BYTES && frameLength <= bytes.size - offset) {
                "Invalid Hive frame length"
            }
            val crcOffset = offset + frameLength - CRC_BYTES
            val expectedCrc = littleEndianUInt(bytes, crcOffset)
            val actualCrc = crc32(bytes, offset, frameLength - CRC_BYTES, keyCrc)
            require(actualCrc == expectedCrc) { "Hive frame checksum failed" }

            val frame = Cursor(bytes, offset + LENGTH_BYTES, crcOffset)
            val keyType = frame.readByte()
            val name = when (keyType) {
                STRING_KEY -> frame.readString(frame.readByte())
                else -> throw IllegalArgumentException("Unsupported Hive key type")
            }
            if (frame.remaining == 0) {
                values.remove(name)
            } else {
                val encrypted = frame.readBytes(frame.remaining)
                require(encrypted.size >= IV_BYTES + BLOCK_BYTES && encrypted.size % BLOCK_BYTES == 0) {
                    "Invalid encrypted Hive value"
                }
                val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    SecretKeySpec(key, "AES"),
                    IvParameterSpec(encrypted, 0, IV_BYTES),
                )
                val plain = cipher.doFinal(encrypted, IV_BYTES, encrypted.size - IV_BYTES)
                values[name] = Cursor(plain, 0, plain.size).readValue()
            }
            offset += frameLength
        }
        return values
    }

    private class Cursor(
        private val bytes: ByteArray,
        private var offset: Int,
        private val limit: Int,
    ) {
        val remaining: Int get() = limit - offset

        fun readValue(depth: Int = 0): Any? {
            require(depth <= MAX_DEPTH) { "Hive value is too deeply nested" }
            return when (val type = readByte()) {
                NULL_TYPE -> null
                INT_TYPE, DOUBLE_TYPE -> readDouble()
                BOOL_TYPE -> readByte() > 0
                STRING_TYPE -> readString(readLength())
                BYTE_LIST_TYPE -> readBytes(readLength())
                INT_LIST_TYPE, DOUBLE_LIST_TYPE -> List(readLength()) { readDouble() }
                BOOL_LIST_TYPE -> List(readLength()) { readByte() > 0 }
                STRING_LIST_TYPE -> List(readLength()) { readString(readLength()) }
                LIST_TYPE -> List(readLength()) { readValue(depth + 1) }
                MAP_TYPE -> {
                    val size = readLength()
                    val result = LinkedHashMap<Any?, Any?>(size)
                    repeat(size) { result[readValue(depth + 1)] = readValue(depth + 1) }
                    result
                }
                else -> throw IllegalArgumentException("Unsupported Hive value type: $type")
            }
        }

        fun readByte(): Int {
            require(remaining >= 1) { "Truncated Hive value" }
            return bytes[offset++].toInt() and 0xff
        }

        fun readBytes(count: Int): ByteArray {
            require(count >= 0 && count <= remaining) { "Truncated Hive value" }
            return bytes.copyOfRange(offset, offset + count).also { offset += count }
        }

        fun readString(count: Int): String {
            val encoded = readBytes(count)
            return Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(encoded))
                .toString()
        }

        private fun readDouble(): Double {
            require(remaining >= Double.SIZE_BYTES) { "Truncated Hive number" }
            return ByteBuffer.wrap(readBytes(Double.SIZE_BYTES)).order(ByteOrder.LITTLE_ENDIAN).double
        }

        private fun readLength(): Int {
            require(remaining >= LENGTH_BYTES) { "Truncated Hive collection" }
            val length = littleEndianUInt(bytes, offset)
            offset += LENGTH_BYTES
            require(length <= remaining && length <= MAX_COLLECTION_ITEMS) { "Invalid Hive collection size" }
            return length.toInt()
        }
    }

    private companion object {
        const val MAX_BOX_BYTES = 256L * 1024 * 1024
        const val KEY_BYTES = 32
        const val LENGTH_BYTES = 4
        const val CRC_BYTES = 4
        const val MIN_FRAME_BYTES = 8
        const val IV_BYTES = 16
        const val BLOCK_BYTES = 16
        const val STRING_KEY = 1
        const val NULL_TYPE = 0
        const val INT_TYPE = 1
        const val DOUBLE_TYPE = 2
        const val BOOL_TYPE = 3
        const val STRING_TYPE = 4
        const val BYTE_LIST_TYPE = 5
        const val INT_LIST_TYPE = 6
        const val DOUBLE_LIST_TYPE = 7
        const val BOOL_LIST_TYPE = 8
        const val STRING_LIST_TYPE = 9
        const val LIST_TYPE = 10
        const val MAP_TYPE = 11
        const val MAX_DEPTH = 32
        const val MAX_COLLECTION_ITEMS = 1_000_000L
    }
}

private fun littleEndianUInt(bytes: ByteArray, offset: Int): Long {
    require(offset >= 0 && offset + 4 <= bytes.size) { "Truncated Hive integer" }
    return (bytes[offset].toLong() and 0xff) or
        ((bytes[offset + 1].toLong() and 0xff) shl 8) or
        ((bytes[offset + 2].toLong() and 0xff) shl 16) or
        ((bytes[offset + 3].toLong() and 0xff) shl 24)
}

private val CRC_TABLE = LongArray(256) { value ->
    var crc = value.toLong()
    repeat(8) { crc = if (crc and 1 != 0L) (crc ushr 1) xor 0xedb88320L else crc ushr 1 }
    crc and 0xffffffffL
}

private fun crc32(bytes: ByteArray, offset: Int = 0, length: Int = bytes.size, initial: Long = 0): Long {
    var crc = initial xor 0xffffffffL
    for (index in offset until offset + length) {
        val tableIndex = ((crc xor (bytes[index].toLong() and 0xff)) and 0xff).toInt()
        crc = CRC_TABLE[tableIndex] xor (crc ushr 8)
    }
    return crc xor 0xffffffffL
}
