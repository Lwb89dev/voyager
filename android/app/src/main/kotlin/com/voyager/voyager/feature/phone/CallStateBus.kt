package com.voyager.voyager.feature.phone

import android.telecom.Call
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class CallInfo(
    val number: String,
    val ringing: Boolean,
)

object CallStateBus {
    private val calls = linkedMapOf<Call, Call.Callback>()
    private val _state = MutableStateFlow<CallInfo?>(null)
    val state: StateFlow<CallInfo?> = _state

    @Synchronized
    fun add(call: Call) {
        if (calls.containsKey(call)) return
        val callback = object : Call.Callback() {
            override fun onStateChanged(changedCall: Call, state: Int) {
                refresh()
            }
        }
        calls[call] = callback
        call.registerCallback(callback)
        refresh()
    }

    @Synchronized
    fun remove(call: Call) {
        calls.remove(call)?.let(call::unregisterCallback)
        refresh()
    }

    @Synchronized
    fun clear() {
        calls.forEach { (call, callback) -> call.unregisterCallback(callback) }
        calls.clear()
        refresh()
    }

    fun answer(): Boolean {
        val call = synchronized(this) {
            calls.keys.lastOrNull { it.details.state == Call.STATE_RINGING }
        } ?: return false
        call.answer(android.telecom.VideoProfile.STATE_AUDIO_ONLY)
        refresh()
        return true
    }

    fun reject(): Boolean {
        val call = synchronized(this) { currentCall() } ?: return false
        call.disconnect()
        refresh()
        return true
    }

    @Synchronized
    private fun refresh() {
        val call = currentCall()
        _state.value = call?.let {
            CallInfo(
                number = it.details.handle?.schemeSpecificPart.orEmpty(),
                ringing = it.details.state == Call.STATE_RINGING,
            )
        }
    }

    private fun currentCall(): Call? = calls.keys.lastOrNull { it.details.state != Call.STATE_DISCONNECTED }
}
