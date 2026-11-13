package ca.wabble.wabway

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Trail mode's state on disk, so the service, the wake-up receiver (which can
 * run with the app closed) and the Flutter screen all see the same thing —
 * with no signal, nothing can be fetched from Supabase.
 */
class TrailStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("wabway_trail", Context.MODE_PRIVATE)

    data class Peer(
        val index: Int,
        val lat: Double?,
        val lng: Double?,
        val accuracyM: Int?,
        val fixTimeMs: Long?,
        val heardAtMs: Long,
        /** Who we heard it from, or -1 when heard straight from their phone. */
        val via: Int,
        val rssi: Int?,
    ) {
        fun toJson(names: List<String>): JSONObject = JSONObject().apply {
            put("index", index)
            put("name", names.getOrNull(index) ?: "Someone")
            if (lat != null) put("lat", lat)
            if (lng != null) put("lng", lng)
            if (accuracyM != null) put("acc", accuracyM)
            if (fixTimeMs != null) put("fixTime", fixTimeMs)
            put("heardAt", heardAtMs)
            put("via", via)
            if (via >= 0) put("viaName", names.getOrNull(via) ?: "Someone")
            if (rssi != null) put("rssi", rssi)
        }

        companion object {
            fun fromJson(o: JSONObject) = Peer(
                index = o.getInt("index"),
                lat = if (o.has("lat")) o.getDouble("lat") else null,
                lng = if (o.has("lng")) o.getDouble("lng") else null,
                accuracyM = if (o.has("acc")) o.getInt("acc") else null,
                fixTimeMs = if (o.has("fixTime")) o.getLong("fixTime") else null,
                heardAtMs = o.getLong("heardAt"),
                via = o.optInt("via", -1),
                rssi = if (o.has("rssi")) o.getInt("rssi") else null,
            )
        }
    }

    var tripId: String
        get() = prefs.getString("tripId", "") ?: ""
        set(v) = prefs.edit().putString("tripId", v).apply()

    var myIndex: Int
        get() = prefs.getInt("myIndex", -1)
        set(v) = prefs.edit().putInt("myIndex", v).apply()

    /** Display names in member-index order (members sorted by user id). */
    var names: List<String>
        get() {
            val arr = JSONArray(prefs.getString("names", "[]"))
            return List(arr.length()) { arr.getString(it) }
        }
        set(v) = prefs.edit().putString("names", JSONArray(v).toString()).apply()

    var wakeEnabled: Boolean
        get() = prefs.getBoolean("wake", true)
        set(v) = prefs.edit().putBoolean("wake", v).apply()

    /** After you stop Trail mode yourself, others' beacons only notify you until then. */
    var snoozeUntilMs: Long
        get() = prefs.getLong("snoozeUntil", 0)
        set(v) = prefs.edit().putLong("snoozeUntil", v).apply()

    var lastWakeNoticeMs: Long
        get() = prefs.getLong("lastWakeNotice", 0)
        set(v) = prefs.edit().putLong("lastWakeNotice", v).apply()

    var startedAtMs: Long
        get() = prefs.getLong("startedAt", 0)
        set(v) = prefs.edit().putLong("startedAt", v).apply()

    var wokenBy: String?
        get() = prefs.getString("wokenBy", null)
        set(v) = prefs.edit().putString("wokenBy", v).apply()

    var myFix: TrailBeacon.Fix?
        get() {
            val s = prefs.getString("myFix", null) ?: return null
            val o = JSONObject(s)
            return TrailBeacon.Fix(o.getDouble("lat"), o.getDouble("lng"), o.getInt("acc"), o.getLong("time"))
        }
        set(v) = prefs.edit().putString(
            "myFix",
            v?.let { JSONObject().put("lat", it.lat).put("lng", it.lng).put("acc", it.accuracyM).put("time", it.timeMs).toString() },
        ).apply()

    var peers: Map<Int, Peer>
        get() {
            val arr = JSONArray(prefs.getString("peers", "[]"))
            return (0 until arr.length()).map { Peer.fromJson(arr.getJSONObject(it)) }.associateBy { it.index }
        }
        set(v) {
            val n = names
            prefs.edit().putString("peers", JSONArray(v.values.map { it.toJson(n) }).toString()).apply()
        }

    val configured: Boolean get() = tripId.isNotEmpty() && myIndex >= 0

    /** Everything the Flutter screen shows, as JSON. */
    fun stateJson(running: Boolean, live: Map<Int, Peer>? = null): String {
        val n = names
        return JSONObject().apply {
            put("running", running)
            put("startedAt", startedAtMs)
            wokenBy?.let { put("wokenBy", it) }
            put("wake", wakeEnabled)
            put("tripId", tripId)
            myFix?.let {
                put("me", JSONObject().put("lat", it.lat).put("lng", it.lng).put("acc", it.accuracyM).put("time", it.timeMs))
            }
            put("peers", JSONArray((live ?: peers).values.map { it.toJson(n) }))
        }.toString()
    }
}
