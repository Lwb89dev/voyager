package com.voyager.voyager.feature.weather

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WeatherRepositoryTest {
    @Test
    fun currentConditionsAndTownAreParsed() {
        val data = WeatherRepository.parseWeather(
            JSONObject("""{"current":{"temperature_2m":17.4,"weather_code":61,"wind_speed_10m":23.8}}"""),
            WeatherLocation(41.9, 12.5),
            nowEpochMs = 1234,
        )
        assertEquals(17.4, data.temperatureCelsius, 0.0)
        assertEquals(61, data.code)
        assertEquals(23.8, data.windKmh, 0.0)
        assertEquals(1234, data.fetchedAtEpochMs)

        val town = JSONObject("""{"address":{"state":"Lazio","city":"Roma"}}""")
        assertEquals("Roma", WeatherRepository.townFrom(town))
        assertNull(WeatherRepository.townFrom(JSONObject("{}")))
    }

    @Test
    fun requestsRoundCoordinatesAndUseBoundedCityLookup() = runTest {
        val server = MockWebServer()
        server.enqueue(
            MockResponse().setBody(
                """{"current":{"temperature_2m":17.4,"weather_code":61,"wind_speed_10m":23.8}}""",
            ),
        )
        server.enqueue(MockResponse().setBody("""{"address":{"city":"Roma"}}"""))
        server.start()
        val cache = MemoryCache()
        val repository = WeatherRepository(
            cache = cache,
            forecastEndpoint = server.url("/forecast").toString(),
            reverseEndpoint = server.url("/reverse").toString(),
        )
        val location = WeatherLocation(41.9028, 12.4964)
        val data = repository.fetch(location, nowEpochMs = 1234)

        val forecast = server.takeRequest()
        assertEquals("41.90", forecast.requestUrl!!.queryParameter("latitude"))
        assertEquals("12.50", forecast.requestUrl!!.queryParameter("longitude"))
        assertEquals("kmh", forecast.requestUrl!!.queryParameter("wind_speed_unit"))
        assertEquals(data, cache.data)

        assertEquals("Roma", repository.placeName(location))
        val reverse = server.takeRequest()
        assertEquals("41.90", reverse.requestUrl!!.queryParameter("lat"))
        assertEquals("12.50", reverse.requestUrl!!.queryParameter("lon"))
        assertEquals("10", reverse.requestUrl!!.queryParameter("zoom"))
        assertEquals("Voyager/0.3.0", reverse.getHeader("User-Agent"))
        server.shutdown()
    }

    private class MemoryCache : WeatherCache {
        var data: WeatherData? = null
        override fun load(): WeatherData? = data
        override fun save(data: WeatherData) {
            this.data = data
        }
    }
}
