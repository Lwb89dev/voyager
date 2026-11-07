package com.voyager.voyager.feature.podcast

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

interface PodcastSubscriptionStore {
    fun load(): List<PodcastSubscription>
    fun save(subscriptions: List<PodcastSubscription>)
}

class SharedPreferencesPodcastSubscriptionStore(context: Context) : PodcastSubscriptionStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        "voyager_podcasts",
        Context.MODE_PRIVATE,
    )

    @Synchronized
    override fun load(): List<PodcastSubscription> {
        val raw = preferences.getString(KEY_SUBSCRIPTIONS, null) ?: return emptyList()
        val array = JSONArray(raw)
        return buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                val feedUrl = item.getString("feedUrl").trim()
                if (feedUrl.isNotEmpty()) {
                    add(
                        PodcastSubscription(
                            feedUrl = feedUrl,
                            title = item.optString("title").ifBlank { feedUrl },
                            imageUrl = item.optString("imageUrl").takeIf(String::isNotBlank),
                        ),
                    )
                }
            }
        }.distinctBy(PodcastSubscription::feedUrl)
    }

    @Synchronized
    override fun save(subscriptions: List<PodcastSubscription>) {
        val array = JSONArray()
        subscriptions.distinctBy(PodcastSubscription::feedUrl).forEach { subscription ->
            array.put(
                JSONObject()
                    .put("feedUrl", subscription.feedUrl)
                    .put("title", subscription.title)
                    .put("imageUrl", subscription.imageUrl),
            )
        }
        check(preferences.edit().putString(KEY_SUBSCRIPTIONS, array.toString()).commit()) {
            "Podcast subscriptions could not be saved"
        }
    }

    companion object {
        private const val KEY_SUBSCRIPTIONS = "subscriptions_v1"
    }
}
