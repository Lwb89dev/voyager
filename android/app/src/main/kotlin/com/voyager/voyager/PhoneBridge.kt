package com.voyager.voyager

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.telecom.TelecomManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Android telephony and SMS onto the two method channels the phone
 * plugin listens on.
 *
 * Scope is deliberately narrow. Voyager reports who is calling, answers,
 * rejects, and forwards the text of an arriving SMS — and does nothing else.
 * There is no call log read, no contact enumeration, no message store access
 * and no persistence of any kind on this side of the bridge: everything is
 * handed straight to Dart, which holds it in memory for the drive and drops it.
 *
 * Note on answering: END_CALL and ANSWER require the app to hold the relevant
 * permission, and on Android 9+ answering goes through TelecomManager rather
 * than the old ITelephony reflection trick, which no longer works and never
 * should have. Audio routing is not touched at all — when the phone is paired
 * to the car over HFP, the car owns the audio and Voyager has no business
 * intervening.
 */
class PhoneBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val phoneChannel = MethodChannel(messenger, PHONE_CHANNEL)
    private val smsChannel = MethodChannel(messenger, SMS_CHANNEL)

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
            // A long text arrives as several PDUs; concatenating the parts is
            // the difference between reading a message and reading its first
            // 160 characters.
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            if (messages.isEmpty()) return
            val sender = messages[0].displayOriginatingAddress ?: ""
            val body = messages.joinToString("") { it.displayMessageBody ?: "" }
            smsChannel.invokeMethod(
                "messageReceived",
                mapOf("sender" to sender, "body" to body),
            )
        }
    }

    init {
        phoneChannel.setMethodCallHandler(::onPhoneCall)
        smsChannel.setMethodCallHandler(::onSmsCall)
        registerSmsReceiver()
    }

    private fun onPhoneCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(hasTelephony() && hasPermission(Manifest.permission.ANSWER_PHONE_CALLS))
            "answerCall" -> result.success(answerCall())
            "rejectCall" -> result.success(rejectCall())
            else -> result.notImplemented()
        }
    }

    private fun onSmsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(hasPermission(Manifest.permission.RECEIVE_SMS))
            else -> result.notImplemented()
        }
    }

    private fun registerSmsReceiver() {
        if (!hasPermission(Manifest.permission.RECEIVE_SMS)) return
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        // RECEIVER_NOT_EXPORTED is required from Android 14 and is correct on
        // every version: the only sender Voyager accepts is the system.
        ContextCompat.registerReceiver(
            context,
            smsReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    private fun telecom(): TelecomManager? =
        context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

    private fun answerCall(): Boolean {
        if (!hasPermission(Manifest.permission.ANSWER_PHONE_CALLS)) return false
        val manager = telecom() ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.acceptRingingCall()
                true
            } else {
                false
            }
        } catch (error: SecurityException) {
            false
        }
    }

    private fun rejectCall(): Boolean {
        if (!hasPermission(Manifest.permission.ANSWER_PHONE_CALLS)) return false
        val manager = telecom() ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                manager.endCall()
            } else {
                false
            }
        } catch (error: SecurityException) {
            false
        }
    }

    private fun hasTelephony(): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED

    fun dispose() {
        phoneChannel.setMethodCallHandler(null)
        smsChannel.setMethodCallHandler(null)
        try {
            context.unregisterReceiver(smsReceiver)
        } catch (error: IllegalArgumentException) {
            // Never registered, because the SMS permission was refused.
        }
    }

    private companion object {
        const val PHONE_CHANNEL = "com.voyager.voyager/phone"
        const val SMS_CHANNEL = "com.voyager.voyager/sms"
    }
}
