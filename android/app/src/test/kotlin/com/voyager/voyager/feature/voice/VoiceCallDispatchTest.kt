package com.voyager.voyager.feature.voice

import org.junit.Assert.assertEquals
import org.junit.Test

class VoiceCallDispatchTest {
    private val parser = VoiceCommandParser(VoiceLanguage.ENGLISH)

    @Test
    fun answerAndRejectAreRequestedOnlyWhenTelecomAcceptsTheAction() {
        var answers = 0
        var rejections = 0
        val dispatcher = dispatcher(answer = { answers += 1; true }, reject = { rejections += 1; true })

        assertEquals(VoiceDispatchResult.REQUESTED, dispatcher.dispatch(parser.parse("answer")))
        assertEquals(VoiceDispatchResult.REQUESTED, dispatcher.dispatch(parser.parse("reject")))
        assertEquals(1, answers)
        assertEquals(1, rejections)
    }

    @Test
    fun missingCallIsReportedAsUnsupportedInsteadOfSuccess() {
        val dispatcher = dispatcher(answer = { false }, reject = { false })
        assertEquals(VoiceDispatchResult.UNSUPPORTED, dispatcher.dispatch(parser.parse("answer")))
        assertEquals(VoiceDispatchResult.UNSUPPORTED, dispatcher.dispatch(parser.parse("reject")))
    }

    private fun dispatcher(answer: () -> Boolean, reject: () -> Boolean) = VoiceCommandDispatcher(
        playMusic = {},
        playPause = {},
        nextTrack = {},
        previousTrack = {},
        showNavigation = {},
        showWeather = {},
        answerCall = answer,
        rejectCall = reject,
    )
}
