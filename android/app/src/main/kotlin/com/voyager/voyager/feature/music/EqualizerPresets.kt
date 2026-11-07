package com.voyager.voyager.feature.music

enum class EqualizerPreset(val anchors: List<Double>) {
    FLAT(listOf(0.0, 0.0, 0.0, 0.0, 0.0)),
    ROAD_NOISE(listOf(0.75, 0.5, 0.0, 0.1, 0.2)),
    SPEECH(listOf(-0.4, -0.2, 0.3, 0.5, 0.2)),
    BOOST(listOf(0.6, 0.25, -0.2, 0.3, 0.55)),
    ROCK(listOf(0.35, -0.44, -0.26, 0.37, 0.63)),
    POP(listOf(0.06, 0.43, 0.30, -0.15, -0.16)),
    JAZZ(listOf(0.15, -0.20, 0.10, -0.05, 0.20)),
    METAL(listOf(0.45, -0.35, -0.10, 0.35, 0.45)),
    RAP(listOf(0.55, -0.15, 0.10, 0.30, 0.15)),
    CUSTOM(listOf(0.0, 0.0, 0.0, 0.0, 0.0));

    fun shape(bandCount: Int): List<Double> = resample(anchors, bandCount)

    fun gains(bandCount: Int, minDecibels: Double, maxDecibels: Double): List<Double> =
        shape(bandCount).map { fraction ->
            if (fraction >= 0) fraction * maxDecibels else fraction * -minDecibels
        }

    companion object {
        fun resample(anchors: List<Double>, count: Int): List<Double> {
            if (count <= 0) return emptyList()
            require(anchors.isNotEmpty()) { "At least one anchor is required" }
            if (count == 1) return listOf(anchors.first())
            return List(count) { index ->
                val position = index.toDouble() / (count - 1) * (anchors.lastIndex)
                val lower = position.toInt()
                val upper = if (lower == anchors.lastIndex) lower else lower + 1
                val fraction = position - lower
                anchors[lower] * (1 - fraction) + anchors[upper] * fraction
            }
        }
    }
}
