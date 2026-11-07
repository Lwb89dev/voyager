package com.voyager.voyager.feature.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceCommandTest {
    private val english = VoiceCommandParser(VoiceLanguage.ENGLISH)
    private val italian = VoiceCommandParser(VoiceLanguage.ITALIAN)

    @Test
    fun plainPhrasesPunctuationAndExtraWordsAreMatched() {
        assertEquals(VoiceIntent.NEXT_TRACK, english.parse("Erm, NEXT TRACK please!").intent)
        assertEquals(VoiceIntent.PREVIOUS_TRACK, english.parse("previous song").intent)
        assertEquals(VoiceIntent.PAUSE_MUSIC, english.parse("pause").intent)
        assertEquals(VoiceIntent.NAVIGATE_HOME, english.parse("take me home").intent)
    }

    @Test
    fun italianIsSeparateAndKeepsAccents() {
        assertEquals(VoiceIntent.NEXT_TRACK, italian.parse("brano successivo").intent)
        assertEquals(VoiceIntent.NAVIGATE_HOME, italian.parse("portami a casa").intent)
        assertEquals(VoiceIntent.SHOW_WEATHER, italian.parse("che meteo fa").intent)
        assertEquals(VoiceIntent.UNKNOWN, italian.parse("next track").intent)
        assertEquals(VoiceIntent.UNKNOWN, italian.parse("più").intent)
    }

    @Test
    fun unknownAndLowConfidenceCommandsAreNotActionable() {
        assertFalse(english.parse("open the pod bay doors").isActionable)
        val quiet = english.parse("next track", confidence = 0.4)
        assertEquals(VoiceIntent.NEXT_TRACK, quiet.intent)
        assertFalse(quiet.isActionable)
        assertTrue(english.parse("next track", confidence = 0.9).isActionable)
    }

    @Test
    fun keywordsInsideOtherWordsDoNotTriggerActions() {
        assertEquals(VoiceIntent.UNKNOWN, english.parse("display").intent)
        assertEquals(VoiceIntent.UNKNOWN, english.parse("skipper").intent)
        assertEquals(VoiceIntent.UNKNOWN, english.parse("weathering").intent)
    }

    @Test
    fun dispatcherInvokesOnlyTheRequestedController() {
        val actions = mutableListOf<String>()
        val dispatcher = VoiceCommandDispatcher(
            playMusic = { actions += "play" },
            playPause = { actions += "pause" },
            nextTrack = { actions += "next" },
            previousTrack = { actions += "previous" },
            showNavigation = { actions += "navigation" },
            showWeather = { actions += "weather" },
        )
        val commands = listOf(
            "play music",
            "pause",
            "next track",
            "previous track",
            "show map",
            "weather",
        )
        commands.forEach {
            assertEquals(
                VoiceDispatchResult.REQUESTED,
                dispatcher.dispatch(english.parse(it)),
            )
        }
        assertEquals(listOf("play", "pause", "next", "previous", "navigation", "weather"), actions)
    }

    @Test
    fun unsupportedAndRejectedCommandsHaveNoSideEffects() {
        var calls = 0
        val dispatcher = VoiceCommandDispatcher(
            playMusic = { calls += 1 },
            playPause = { calls += 1 },
            nextTrack = { calls += 1 },
            previousTrack = { calls += 1 },
            showNavigation = { calls += 1 },
            showWeather = { calls += 1 },
        )
        assertEquals(VoiceDispatchResult.UNSUPPORTED, dispatcher.dispatch(english.parse("take me home")))
        assertEquals(VoiceDispatchResult.UNSUPPORTED, dispatcher.dispatch(english.parse("answer")))
        assertEquals(VoiceDispatchResult.UNKNOWN, dispatcher.dispatch(english.parse("gibberish")))
        assertEquals(
            VoiceDispatchResult.LOW_CONFIDENCE,
            dispatcher.dispatch(english.parse("next track", confidence = 0.2)),
        )
        assertEquals(0, calls)
    }
}
