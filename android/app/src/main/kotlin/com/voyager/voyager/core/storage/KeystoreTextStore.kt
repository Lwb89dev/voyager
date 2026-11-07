package com.voyager.voyager.core.storage

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class KeystoreTextStore(
    context: Context,
    name: String,
    private val keyAlias: String,
) {
    private val file = File(context.noBackupFilesDir, "$name.secret")
    private val lock = Any()

    fun read(): String? = synchronized(lock) {
        if (!file.isFile) return@synchronized null
        val bytes = file.readBytes()
        require(bytes.size > VERSION_SIZE + IV_SIZE) { "Protected value is truncated" }
        val buffer = ByteBuffer.wrap(bytes)
        require(buffer.get() == VERSION) { "Unsupported protected-value version" }
        val iv = ByteArray(IV_SIZE).also(buffer::get)
        val ciphertext = ByteArray(buffer.remaining()).also(buffer::get)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(IV_SIZE * 8, iv))
        String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }

    fun write(value: String) = synchronized(lock) {
        val iv = ByteArray(IV_SIZE)
        java.security.SecureRandom().nextBytes(iv)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key(), GCMParameterSpec(IV_SIZE * 8, iv))
        val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val encoded = ByteBuffer.allocate(VERSION_SIZE + IV_SIZE + ciphertext.size)
            .put(VERSION)
            .put(iv)
            .put(ciphertext)
            .array()
        file.parentFile?.mkdirs()
        val stage = File(file.parentFile, "${file.name}.stage")
        val backup = File(file.parentFile, "${file.name}.backup")
        stage.outputStream().use { output ->
            output.write(encoded)
            output.fd.sync()
        }
        require(stage.readBytes().contentEquals(encoded)) { "Protected value could not be verified" }
        if (file.isFile) file.copyTo(backup, overwrite = true)
        check(stage.renameTo(file)) { "Protected value could not be committed" }
        read()
        Unit
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val VERSION = 1.toByte()
        const val VERSION_SIZE = 1
        const val IV_SIZE = 12
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
