package com.voyager.voyager.feature.voice

enum class VoiceDispatchResult {
    REQUESTED,
    LOW_CONFIDENCE,
    UNKNOWN,
    UNSUPPORTED,
}

class VoiceCommandDispatcher(
    private val playMusic: () -> Unit,
    private val playPause: () -> Unit,
    private val nextTrack: () -> Unit,
    private val previousTrack: () -> Unit,
    private val showNavigation: () -> Unit,
    private val showWeather: () -> Unit,
    private val answerCall: () -> Boolean = { false },
    private val rejectCall: () -> Boolean = { false },
) {
    fun dispatch(command: VoiceCommand): VoiceDispatchResult {
        if (command.intent == VoiceIntent.UNKNOWN) return VoiceDispatchResult.UNKNOWN
        if (!command.isActionable) return VoiceDispatchResult.LOW_CONFIDENCE
        if (command.intent == VoiceIntent.ANSWER_CALL) {
            return if (answerCall()) VoiceDispatchResult.REQUESTED else VoiceDispatchResult.UNSUPPORTED
        }
        if (command.intent == VoiceIntent.REJECT_CALL) {
            return if (rejectCall()) VoiceDispatchResult.REQUESTED else VoiceDispatchResult.UNSUPPORTED
        }
        val action = when (command.intent) {
            VoiceIntent.PLAY_MUSIC -> playMusic
            VoiceIntent.PAUSE_MUSIC -> playPause
            VoiceIntent.NEXT_TRACK -> nextTrack
            VoiceIntent.PREVIOUS_TRACK -> previousTrack
            VoiceIntent.SHOW_NAVIGATION -> showNavigation
            VoiceIntent.SHOW_WEATHER -> showWeather
            VoiceIntent.NAVIGATE_HOME,
            VoiceIntent.CANCEL_ROUTE,
            VoiceIntent.READ_MESSAGES,
            -> return VoiceDispatchResult.UNSUPPORTED
            VoiceIntent.ANSWER_CALL,
            VoiceIntent.REJECT_CALL,
            -> return VoiceDispatchResult.UNSUPPORTED
            VoiceIntent.UNKNOWN -> return VoiceDispatchResult.UNKNOWN
        }
        action()
        return VoiceDispatchResult.REQUESTED
    }
}
