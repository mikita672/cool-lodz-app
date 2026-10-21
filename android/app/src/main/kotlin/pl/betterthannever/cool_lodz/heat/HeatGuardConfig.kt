package pl.betterthannever.cool_lodz.heat

import android.content.Context
import org.json.JSONObject

/**
 * Settings from the Flutter side (JSON in SharedPreferences, so the service
 * can restart on its own):
 * `{"waitMinutes": 7, "heatOnly": true, "hotCelsius": 28, "heatUntil": 0,
 *   "contacts": [{"name": "Anna", "phone": "+48…"}], "home": [lat, lon],
 *   "safePlaces": [[lat, lon], …], "texts": {key: text}}`.
 */
class HeatGuardConfig(json: JSONObject) {
    val waitMinutes = json.optInt("waitMinutes", 7).coerceIn(1, 60)
    val heatOnly = json.optBoolean("heatOnly", true)
    val hotCelsius = json.optDouble("hotCelsius", 28.0)
    val heatUntil = json.optLong("heatUntil", 0)
    val contacts: List<Pair<String, String>> = json.optJSONArray("contacts")?.let { a ->
        (0 until a.length()).mapNotNull { i ->
            a.optJSONObject(i)?.let { it.optString("name") to it.optString("phone") }
        }.filter { it.second.isNotBlank() }
    } ?: emptyList()
    val home: Pair<Double, Double>? = json.optJSONArray("home")?.let {
        if (it.length() == 2) it.getDouble(0) to it.getDouble(1) else null
    }
    val safePlaces: List<Pair<Double, Double>> = json.optJSONArray("safePlaces")?.let { a ->
        (0 until a.length()).mapNotNull { i ->
            a.optJSONArray(i)?.takeIf { it.length() == 2 }?.let { it.getDouble(0) to it.getDouble(1) }
        }
    } ?: emptyList()
    private val texts = json.optJSONObject("texts") ?: JSONObject()

    fun text(key: String, vararg args: Pair<String, String>): String {
        var s = texts.optString(key, key)
        for ((k, v) in args) s = s.replace("{$k}", v)
        return s
    }

    companion object {
        private const val PREFS = "heat_guard"
        private const val KEY = "config"

        fun save(context: Context, json: String) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()

        fun load(context: Context): HeatGuardConfig? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)?.let {
                try {
                    HeatGuardConfig(JSONObject(it))
                } catch (_: Exception) {
                    null
                }
            }
    }
}
