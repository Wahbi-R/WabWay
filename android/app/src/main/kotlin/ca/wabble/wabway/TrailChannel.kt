package ca.wabble.wabway

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ Trail mode. Method channel `ca.wabble.wabway/trail` (setup checks,
 * permissions, start/stop, wake), event channels `…/trail_events` (state JSON)
 * and `…/compass` (heading in degrees).
 */
class TrailChannel(private val activity: Activity, messenger: BinaryMessenger) {

    companion object {
        const val PERMISSION_REQUEST = 7420
    }

    val methods = MethodChannel(messenger, "ca.wabble.wabway/trail")
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null
    private val store = TrailStore(activity)

    init {
        methods.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "configure" -> {
                        val tripId = call.argument<String>("tripId") ?: ""
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        val myIndex = call.argument<Int>("myIndex") ?: -1
                        if (tripId != store.tripId) store.peers = emptyMap()
                        store.tripId = tripId
                        store.names = names
                        store.myIndex = myIndex
                        TrailWake.refresh(activity)
                        result.success(null)
                    }
                    "state" -> result.success(store.stateJson(TrailService.running))
                    "setup" -> result.success(setupStatus())
                    "start" -> {
                        TrailService.start(activity)
                        result.success(true)
                    }
                    "stop" -> {
                        TrailService.stop(activity)
                        result.success(null)
                    }
                    "setWake" -> {
                        store.wakeEnabled = call.argument<Boolean>("enabled") ?: true
                        result.success(TrailWake.refresh(activity))
                    }
                    "refreshWake" -> result.success(TrailWake.refresh(activity))
                    "clearPeers" -> {
                        store.peers = emptyMap()
                        result.success(null)
                    }
                    "requestPermissions" -> requestPermissions(foregroundPermissions(), result)
                    "requestBackgroundLocation" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), result)
                        } else result.success(true)
                    }
                    "requestBatteryUnrestricted" -> {
                        requestBatteryUnrestricted()
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        activity.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")),
                        )
                        result.success(null)
                    }
                    "enableBluetooth" -> {
                        enableBluetooth()
                        result.success(null)
                    }
                    "openLocationSettings" -> {
                        activity.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                        result.success(null)
                    }
                    "takeLaunchAction" -> {
                        val open = activity.intent?.action == MainActivity.OPEN_TRAIL_ACTION
                        if (open) activity.intent = Intent(activity.intent).setAction(Intent.ACTION_MAIN)
                        result.success(open)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("TRAIL", e.message, null)
            }
        }

        EventChannel(messenger, "ca.wabble.wabway/trail_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                TrailService.listener = { json -> main.post { events.success(json) } }
                events.success(store.stateJson(TrailService.running))
            }

            override fun onCancel(arguments: Any?) {
                TrailService.listener = null
            }
        })

        EventChannel(messenger, "ca.wabble.wabway/compass").setStreamHandler(Compass(activity))
    }

    private fun foregroundPermissions(): Array<String> {
        val p = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            p += listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) p += Manifest.permission.POST_NOTIFICATIONS
        return p.toTypedArray()
    }

    private fun granted(p: String) = activity.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun setupStatus(): Map<String, Any> {
        val adapter = (activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        val lm = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        val btPerms = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.BLUETOOTH_CONNECT).all(::granted)
        return mapOf(
            "supported" to (adapter != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)),
            "advertiseSupported" to (adapter?.isMultipleAdvertisementSupported ?: false),
            "bluetoothOn" to (adapter?.isEnabled ?: false),
            "bluetoothPermission" to btPerms,
            "locationPermission" to granted(Manifest.permission.ACCESS_FINE_LOCATION),
            "backgroundLocation" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
            "locationOn" to lm.isProviderEnabled(LocationManager.GPS_PROVIDER),
            "batteryUnrestricted" to pm.isIgnoringBatteryOptimizations(activity.packageName),
            "notifications" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || granted(Manifest.permission.POST_NOTIFICATIONS)),
            "running" to TrailService.running,
        )
    }

    private fun requestPermissions(perms: Array<String>, result: MethodChannel.Result) {
        val missing = perms.filterNot(::granted)
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST)
    }

    /** Forwarded from MainActivity. */
    fun onPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val r = pendingPermission ?: return true
        pendingPermission = null
        r.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        TrailWake.refresh(activity)
        return true
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryUnrestricted() {
        try {
            activity.startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${activity.packageName}")),
            )
        } catch (_: Exception) {
            activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }

    @SuppressLint("MissingPermission")
    private fun enableBluetooth() {
        try {
            activity.startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
        } catch (_: Exception) {
            activity.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
        }
    }

    fun openTrail() {
        methods.invokeMethod("openTrail", null)
    }
}

/** Phone heading (0 = north), for the arrows pointing at the crew. */
private class Compass(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private val rotation = FloatArray(9)
    private val orientation = FloatArray(3)
    private var last = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val s = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (s == null) events.endOfStream() else sensors.registerListener(this, s, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        if (now - last < 80) return
        last = now
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, orientation)
        val deg = (Math.toDegrees(orientation[0].toDouble()) + 360) % 360
        sink?.success(deg)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
