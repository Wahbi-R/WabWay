package ca.wabble.wabway

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

/**
 * Trail mode: keeps a GPS fix (works with no signal), sends it to the crew over
 * Bluetooth, listens for theirs and passes on what it heard, so positions hop
 * between phones. Runs as a foreground service so it keeps going with the
 * screen off; stops by itself after [MAX_RUN_MS].
 */
class TrailService : Service() {

    companion object {
        const val ACTION_START = "ca.wabble.wabway.TRAIL_START"
        const val ACTION_STOP = "ca.wabble.wabway.TRAIL_STOP"
        const val EXTRA_WOKEN_BY = "woken_by"

        const val CHANNEL_ID = "trail_mode"
        const val ALERT_CHANNEL_ID = "trail_alerts"
        private const val NOTIF_ID = 75420
        const val ALERT_NOTIF_ID = 75421

        private const val MAX_RUN_MS = 6 * 60 * 60 * 1000L
        /** Stop passing on someone's position once it's this old. */
        private const val RELAY_MAX_AGE_MS = 40 * 60 * 1000L
        private const val ROTATE_MS = 3_000L
        /** You stopped it yourself: others' beacons only notify you for this long. */
        const val SNOOZE_MS = 2 * 60 * 60 * 1000L

        @Volatile var running = false
            private set

        /** Set by the Flutter event channel while the Trail screen is open. */
        @Volatile var listener: ((String) -> Unit)? = null

        fun start(context: Context, wokenBy: String? = null) {
            val i = Intent(context, TrailService::class.java).setAction(ACTION_START)
            if (wokenBy != null) i.putExtra(EXTRA_WOKEN_BY, wokenBy)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        }

        fun stop(context: Context) {
            context.startService(Intent(context, TrailService::class.java).setAction(ACTION_STOP))
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Trail mode", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Shown while Trail mode is finding your crew" },
            )
            nm.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL_ID, "Trail mode alerts", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "When someone nearby turns on Trail mode" },
            )
        }

        fun openTrailIntent(context: Context): PendingIntent {
            val i = Intent(context, MainActivity::class.java)
                .setAction(MainActivity.OPEN_TRAIL_ACTION)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            return PendingIntent.getActivity(context, 1, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun scanFilter(): ScanFilter = ScanFilter.Builder()
            .setManufacturerData(TrailBeacon.COMPANY_ID, TrailBeacon.MAGIC, TrailBeacon.MAGIC_MASK)
            .build()
    }

    private lateinit var store: TrailStore
    private val handler = Handler(Looper.getMainLooper())
    private val peers = HashMap<Int, TrailStore.Peer>()
    private var tripId = ""
    private var myIndex = -1
    private var names: List<String> = emptyList()
    private var myFix: TrailBeacon.Fix? = null

    private var locationManager: LocationManager? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertising = false
    private var rotation = 0
    private var lastPersist = 0L
    private var lastNotify = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        store = TrailStore(this)
        if (intent?.action == ACTION_STOP) {
            store.snoozeUntilMs = System.currentTimeMillis() + SNOOZE_MS
            shutdown()
            return START_NOT_STICKY
        }
        if (running) return START_STICKY
        if (!store.configured) {
            stopSelf()
            return START_NOT_STICKY
        }
        tripId = store.tripId
        myIndex = store.myIndex
        names = store.names
        myFix = store.myFix
        // Keep what we knew from last time ("last seen 2 h ago" still helps).
        peers.clear()
        peers.putAll(store.peers)

        ensureChannels(this)
        val wokenBy = intent?.getStringExtra(EXTRA_WOKEN_BY)
        store.wokenBy = wokenBy
        store.startedAtMs = System.currentTimeMillis()
        store.snoozeUntilMs = 0
        if (!goForeground(buildNotification())) {
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        startLocation()
        startBluetooth()
        handler.postDelayed(autoStop, MAX_RUN_MS)
        handler.post(rotate)
        publish(force = true)
        return START_STICKY
    }

    /** Location + Bluetooth types when allowed; Bluetooth only if location isn't (started in the background). */
    private fun goForeground(n: Notification): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, n)
            return true
        }
        val both = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        for (type in listOf(both, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)) {
            try {
                startForeground(NOTIF_ID, n, type)
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }

    private val autoStop = Runnable { shutdown() }

    private fun shutdown() {
        handler.removeCallbacksAndMessages(null)
        stopBluetooth()
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (_: Exception) {
        }
        if (running) store.peers = HashMap(peers)
        running = false
        store.startedAtMs = 0
        listener?.let { l -> handler.post { l(store.stateJson(false)) } }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_REMOVE)
        else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        if (running) shutdown()
        super.onDestroy()
    }

    // ── GPS ──────────────────────────────────────────────────────────────────

    private val locationListener = LocationListener { loc -> onLocation(loc) }

    @SuppressLint("MissingPermission")
    private fun startLocation() {
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        locationManager = lm
        try {
            // GPS needs no signal. Network location helps indoors when there is some.
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 10_000L, 3f, locationListener, Looper.getMainLooper())
            }
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 20_000L, 5f, locationListener, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            // No location permission in this run: still relay the crew's positions.
        }
    }

    private fun onLocation(loc: Location) {
        val prev = myFix
        val acc = loc.accuracy.roundToInt()
        // Prefer a fresh accurate fix; take a worse one only if ours is stale.
        if (prev != null && loc.time - prev.timeMs < 30_000L && acc > prev.accuracyM) return
        myFix = TrailBeacon.Fix(loc.latitude, loc.longitude, acc, loc.time)
        store.myFix = myFix
        publish()
    }

    // ── Bluetooth ────────────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    private fun startBluetooth() {
        val adapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter ?: return
        if (!adapter.isEnabled) return
        advertiser = adapter.bluetoothLeAdvertiser
        scanner = adapter.bluetoothLeScanner
        try {
            scanner?.startScan(
                listOf(scanFilter()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build(),
                scanCallback,
            )
        } catch (_: SecurityException) {
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopBluetooth() {
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }
        try {
            if (advertising) advertiser?.stopAdvertising(advertiseCallback)
        } catch (_: Exception) {
        }
        advertising = false
    }

    private val advertiseCallback = object : AdvertiseCallback() {}

    /** Every few seconds send the next packet: ours every other time, the crew's in between. */
    private val rotate = object : Runnable {
        override fun run() {
            advertiseNext()
            handler.postDelayed(this, ROTATE_MS)
        }
    }

    @SuppressLint("MissingPermission")
    private fun advertiseNext() {
        val adv = advertiser ?: run {
            // Bluetooth may have been switched on after we started.
            val adapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
            if (adapter?.isEnabled == true) startBluetooth()
            advertiser
        } ?: return
        val now = System.currentTimeMillis()
        val relays = peers.values
            .filter { it.fixTimeMs != null && now - it.fixTimeMs < RELAY_MAX_AGE_MS }
            .sortedBy { it.index }
        rotation++
        val packet = if (relays.isEmpty() || rotation % 2 == 0) {
            TrailBeacon.Packet(myIndex, myIndex, relayed = false, fix = myFix)
        } else {
            val p = relays[(rotation / 2) % relays.size]
            TrailBeacon.Packet(p.index, myIndex, relayed = true,
                fix = TrailBeacon.Fix(p.lat!!, p.lng!!, p.accuracyM ?: 0, p.fixTimeMs!!))
        }
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addManufacturerData(TrailBeacon.COMPANY_ID, TrailBeacon.encode(tripId, packet, now))
            .build()
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)
            .build()
        try {
            if (advertising) adv.stopAdvertising(advertiseCallback)
            adv.startAdvertising(settings, data, advertiseCallback)
            advertising = true
        } catch (_: Exception) {
            advertising = false
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) = onBeacon(result)
        override fun onBatchScanResults(results: MutableList<ScanResult>) = results.forEach { onBeacon(it) }
    }

    private fun onBeacon(result: ScanResult) {
        val now = System.currentTimeMillis()
        val bytes = result.scanRecord?.getManufacturerSpecificData(TrailBeacon.COMPANY_ID)
        val p = TrailBeacon.decode(tripId, bytes, now) ?: return
        if (p.subject == myIndex || p.subject >= names.size) return
        val direct = p.subject == p.sender
        val old = peers[p.subject]
        val fix = p.fix
        // A relayed position only counts if it's newer than what we have.
        if (!direct && (fix == null || (old?.fixTimeMs != null && fix.timeMs <= old.fixTimeMs))) return
        val newer = fix != null && (old?.fixTimeMs == null || fix.timeMs >= old.fixTimeMs)
        peers[p.subject] = TrailStore.Peer(
            index = p.subject,
            lat = if (newer) fix!!.lat else old?.lat,
            lng = if (newer) fix!!.lng else old?.lng,
            accuracyM = if (newer) fix!!.accuracyM else old?.accuracyM,
            fixTimeMs = if (newer) fix!!.timeMs else old?.fixTimeMs,
            heardAtMs = if (direct) now else (old?.heardAtMs ?: now),
            via = if (direct) -1 else p.sender,
            rssi = if (direct) result.rssi else null,
        )
        publish()
    }

    // ── Updates ──────────────────────────────────────────────────────────────

    private fun publish(force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (force || now - lastPersist > 5_000L) {
            lastPersist = now
            store.peers = HashMap(peers)
        }
        if (force || now - lastNotify > 15_000L) {
            lastNotify = now
            getSystemService(NotificationManager::class.java).notify(NOTIF_ID, buildNotification())
        }
        listener?.invoke(store.stateJson(true, HashMap(peers)))
    }

    private fun buildNotification(): Notification {
        val now = System.currentTimeMillis()
        val me = myFix
        val parts = peers.values
            .filter { now - it.heardAtMs < 10 * 60_000L || (it.fixTimeMs != null && now - it.fixTimeMs < 10 * 60_000L) }
            .sortedBy { it.index }
            .map { p ->
                val name = names.getOrNull(p.index) ?: "Someone"
                if (me != null && p.lat != null && p.lng != null) {
                    val d = FloatArray(1)
                    Location.distanceBetween(me.lat, me.lng, p.lat, p.lng, d)
                    "$name ${fmtDistance(d[0])}"
                } else "$name nearby"
            }
        val text = when {
            parts.isNotEmpty() -> parts.joinToString(" · ")
            store.wokenBy != null -> "${store.wokenBy} turned it on nearby — looking for the crew…"
            else -> "Looking for your crew…"
        }
        val stop = PendingIntent.getService(
            this, 2, Intent(this, TrailService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(resources.getIdentifier("ic_launcher", "mipmap", packageName))
            .setContentTitle("Trail mode is on")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openTrailIntent(this))
            .addAction(0, "Stop", stop)
            .build()
    }

    private fun fmtDistance(m: Float): String =
        if (m < 1000) "${(m / 10).roundToInt() * 10} m" else String.format("%.1f km", m / 1000)
}
