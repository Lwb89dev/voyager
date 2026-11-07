package com.voyager.voyager.feature.voice

enum class VoiceLanguage { ENGLISH, ITALIAN }

enum class VoiceIntent {
    PLAY_MUSIC,
    PAUSE_MUSIC,
    NEXT_TRACK,
    PREVIOUS_TRACK,
    SHOW_NAVIGATION,
    SHOW_WEATHER,
    NAVIGATE_HOME,
    CANCEL_ROUTE,
    READ_MESSAGES,
    ANSWER_CALL,
    REJECT_CALL,
    UNKNOWN,
}

data class VoiceCommand(
    val transcript: String,
    val intent: VoiceIntent,
    val confidence: Double,
) {
    init {
        require(confidence.isFinite() && confidence in 0.0..1.0)
    }

    val isActionable: Boolean
        get() = intent != VoiceIntent.UNKNOWN && confidence >= MIN_CONFIDENCE

    companion object {
        const val MIN_CONFIDENCE = 0.6
    }
}

class VoiceCommandParser(private val language: VoiceLanguage) {
    fun parse(transcript: String, confidence: Double = 1.0): VoiceCommand {
        val normalized = normalize(transcript)
        val padded = " $normalized "
        val phrases = if (language == VoiceLanguage.ITALIAN) ITALIAN else ENGLISH
        val intent = phrases.firstNotNullOfOrNull { (candidate, variants) ->
            candidate.takeIf { variants.any { phrase -> padded.contains(" $phrase ") } }
        } ?: VoiceIntent.UNKNOWN
        return VoiceCommand(transcript, intent, confidence)
    }

    private fun normalize(input: String): String = input
        .lowercase()
        .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()

    companion object {
        private val ENGLISH = linkedMapOf(
            VoiceIntent.PREVIOUS_TRACK to listOf("previous track", "previous song", "go back"),
            VoiceIntent.NEXT_TRACK to listOf("next track", "next song", "skip"),
            VoiceIntent.PAUSE_MUSIC to listOf("pause", "stop the music", "stop music"),
            VoiceIntent.PLAY_MUSIC to listOf("play music", "play something", "play"),
            VoiceIntent.NAVIGATE_HOME to listOf("navigate home", "take me home", "go home"),
            VoiceIntent.CANCEL_ROUTE to listOf("cancel route", "stop navigation"),
            VoiceIntent.SHOW_NAVIGATION to listOf("show map", "show navigation", "navigation"),
            VoiceIntent.SHOW_WEATHER to listOf("weather", "forecast"),
            VoiceIntent.READ_MESSAGES to listOf("read messages", "read my messages"),
            VoiceIntent.ANSWER_CALL to listOf("answer", "pick up", "take the call"),
            VoiceIntent.REJECT_CALL to listOf("reject", "hang up", "decline"),
        )
        private val ITALIAN = linkedMapOf(
            VoiceIntent.PREVIOUS_TRACK to listOf("brano precedente", "canzone precedente", "torna indietro"),
            VoiceIntent.NEXT_TRACK to listOf("brano successivo", "canzone successiva", "salta"),
            VoiceIntent.PAUSE_MUSIC to listOf("pausa", "ferma la musica"),
            VoiceIntent.PLAY_MUSIC to listOf("metti la musica", "metti qualcosa", "suona"),
            VoiceIntent.NAVIGATE_HOME to listOf("portami a casa", "naviga verso casa", "vai a casa"),
            VoiceIntent.CANCEL_ROUTE to listOf("annulla percorso", "ferma la navigazione"),
            VoiceIntent.SHOW_NAVIGATION to listOf("mostra la mappa", "mappa", "navigazione"),
            VoiceIntent.SHOW_WEATHER to listOf("meteo", "previsioni"),
            VoiceIntent.READ_MESSAGES to listOf("leggi i messaggi", "leggi messaggi"),
            VoiceIntent.ANSWER_CALL to listOf("rispondi", "prendi la chiamata"),
            VoiceIntent.REJECT_CALL to listOf("rifiuta", "riaggancia"),
        )
    }
}
