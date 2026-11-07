package com.voyager.voyager.legacy.migration

import android.content.Context
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.MGF1ParameterSpec
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

class FlutterSecureStorageReader(context: Context) {
    private val applicationContext = context.applicationContext
    private val data = applicationContext.getSharedPreferences(DATA_PREFERENCES, Context.MODE_PRIVATE)
    private val keys = applicationContext.getSharedPreferences(KEY_PREFERENCES, Context.MODE_PRIVATE)

    fun read(names: Set<String>): Map<String, String> {
        val wrapped = keys.getString(WRAPPED_AES_KEY, null) ?: throw IllegalStateException("Legacy key is unavailable")
        val keyAlgorithm = data.getString(KEY_ALGORITHM_MARKER, null)
        val storageAlgorithm = data.getString(STORAGE_ALGORITHM_MARKER, null)
        val rsaOaep = when (keyAlgorithm) {
            null -> false
            RSA_OAEP -> true
            RSA_PKCS1 -> false
            else -> throw IllegalStateException("Unsupported legacy key algorithm")
        }
        val gcm = when (storageAlgorithm) {
            null -> false
            AES_GCM -> true
            AES_CBC -> false
            else -> throw IllegalStateException("Unsupported legacy storage algorithm")
        }
        val secretKey = unwrapKey(Base64.getDecoder().decode(wrapped), rsaOaep)
        return buildMap {
            names.forEach { name ->
                val preferenceName = "$KEY_PREFIX$name"
                val encrypted = data.getString(preferenceName, null) ?: return@forEach
                val plain = decrypt(Base64.getDecoder().decode(encrypted), secretKey, gcm)
                put(name, String(plain, Charsets.UTF_8))
            }
        }
    }

    private fun unwrapKey(wrapped: ByteArray, oaep: Boolean): SecretKeySpec {
        val alias = applicationContext.packageName + if (oaep) RSA_OAEP_ALIAS else RSA_PKCS1_ALIAS
        val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val privateKey = store.getKey(alias, null) as? PrivateKey
            ?: throw IllegalStateException("Legacy Keystore key is unavailable")
        val cipher = if (oaep) {
            Cipher.getInstance(RSA_OAEP_TRANSFORMATION, ANDROID_KEYSTORE_WORKAROUND).apply {
                init(
                    Cipher.UNWRAP_MODE,
                    privateKey,
                    OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT),
                )
            }
        } else {
            Cipher.getInstance(RSA_PKCS1_TRANSFORMATION, ANDROID_KEYSTORE_WORKAROUND).apply {
                init(Cipher.UNWRAP_MODE, privateKey)
            }
        }
        return SecretKeySpec(cipher.unwrap(wrapped, "AES", Cipher.SECRET_KEY).encoded, "AES")
    }

    private fun decrypt(encoded: ByteArray, key: SecretKeySpec, gcm: Boolean): ByteArray {
        val ivSize = if (gcm) GCM_IV_BYTES else CBC_IV_BYTES
        require(encoded.size > ivSize) { "Invalid legacy encrypted value" }
        val cipher = Cipher.getInstance(if (gcm) AES_GCM_TRANSFORMATION else AES_CBC_TRANSFORMATION)
        val parameters = if (gcm) {
            GCMParameterSpec(GCM_TAG_BITS, encoded, 0, ivSize)
        } else {
            IvParameterSpec(encoded, 0, ivSize)
        }
        cipher.init(Cipher.DECRYPT_MODE, key, parameters)
        return cipher.doFinal(encoded, ivSize, encoded.size - ivSize)
    }

    private companion object {
        const val DATA_PREFERENCES = "FlutterSecureStorage"
        const val KEY_PREFERENCES = "FlutterSecureKeyStorage"
        const val KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_"
        const val WRAPPED_AES_KEY = "AESVGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK"
        const val KEY_ALGORITHM_MARKER = "FlutterSecureSAlgorithmKey"
        const val STORAGE_ALGORITHM_MARKER = "FlutterSecureSAlgorithmStorage"
        const val RSA_OAEP = "RSA_ECB_OAEPwithSHA_256andMGF1Padding"
        const val RSA_PKCS1 = "RSA_ECB_PKCS1Padding"
        const val AES_GCM = "AES_GCM_NoPadding"
        const val AES_CBC = "AES_CBC_PKCS7Padding"
        const val RSA_OAEP_ALIAS = ".FlutterSecureStoragePluginKeyOAEP"
        const val RSA_PKCS1_ALIAS = ".FlutterSecureStoragePluginKey"
        const val RSA_OAEP_TRANSFORMATION = "RSA/ECB/OAEPPadding"
        const val RSA_PKCS1_TRANSFORMATION = "RSA/ECB/PKCS1Padding"
        const val AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding"
        const val AES_CBC_TRANSFORMATION = "AES/CBC/PKCS7Padding"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val ANDROID_KEYSTORE_WORKAROUND = "AndroidKeyStoreBCWorkaround"
        const val GCM_IV_BYTES = 12
        const val CBC_IV_BYTES = 16
        const val GCM_TAG_BITS = 128
    }
}
