package ca.wabble.wabway

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * "Let the crew wake me": a low-power Bluetooth scan the phone's chip runs on
 * its own (no GPS, no app running), filtered to WabWay beacons. When a crew
 * member's Trail mode is heard, [TrailWakeReceiver] turns Trail mode on here
 * too — or, if Android won't allow that from the background (battery
 * optimisation on) or you stopped it yourself recently, posts a "tap to join"
 * notification.
 */
object TrailWake {
    private const val ACTION_WAKE = "ca.wabble.wabway.TRAIL_WAKE"

    private fun pendingIntent(context: Context): PendingIntent {
        val i = Intent(context, TrailWakeReceiver::class.java).setAction(ACTION_WAKE)
        // MUTABLE: the system adds the scan results to it.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(context, 3, i, flags)
    }

    private fun scanner(context: Context): BluetoothLeScanner? {
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        if (adapter == null || !adapter.isEnabled) return null
        return adapter.bluetoothLeScanner
    }

    private fun canScan(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED

    /** (Re)register the background scan if it's wanted. Safe to call often. */
    @SuppressLint("MissingPermission")
    fun refresh(context: Context): Boolean {
        val store = TrailStore(context)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!store.wakeEnabled || !store.configured || !canScan(context)) {
            disable(context)
            return false
        }
        val s = scanner(context) ?: return false
        return try {
            s.stopScan(pendingIntent(context))
            val code = s.startScan(
                listOf(TrailService.scanFilter()),
                ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                    .setCallbackType(ScanSettings.CALLBACK_TYPE_FIRST_MATCH)
                    .build(),
                pendingIntent(context),
            )
            code == 0
        } catch (_: Exception) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun disable(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !canScan(context)) return
        try {
            scanner(context)?.stopScan(pendingIntent(context))
        } catch (_: Exception) {
        }
    }

    fun onResults(context: Context, results: List<ScanResult>) {
        if (TrailService.running) return
        val store = TrailStore(context)
        if (!store.configured || !store.wakeEnabled) return
        val now = System.currentTimeMillis()
        val names = store.names
        val packet = results.firstNotNullOfOrNull {
            TrailBeacon.decode(store.tripId, it.scanRecord?.getManufacturerSpecificData(TrailBeacon.COMPANY_ID), now)
        } ?: return
        if (packet.sender == store.myIndex) return
        val who = names.getOrNull(packet.sender) ?: "Someone from your crew"

        if (now >= store.snoozeUntilMs) {
            try {
                TrailService.start(context, wokenBy = who)
                notify(context, "Trail mode turned on", "$who is nearby with Trail mode on, so yours is on too.")
                return
            } catch (_: Exception) {
                // Android blocked a background start (battery optimisation) — ask instead.
            }
        }
        if (now - store.lastWakeNoticeMs < 30 * 60_000L) return
        store.lastWakeNoticeMs = now
        notify(context, "$who is nearby with Trail mode on", "Tap to turn yours on and find each other without signal.")
    }

    private fun notify(context: Context, title: String, text: String) {
        TrailService.ensureChannels(context)
        val n = NotificationCompat.Builder(context, TrailService.ALERT_CHANNEL_ID)
            .setSmallIcon(context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName))
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(TrailService.openTrailIntent(context))
            .build()
        try {
            context.getSystemService(NotificationManager::class.java).notify(TrailService.ALERT_NOTIF_ID, n)
        } catch (_: SecurityException) {
            // Notifications not allowed.
        }
    }
}

/** Gets the background scan's results, and re-arms the scan after a reboot. */
class TrailWakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> TrailWake.refresh(context)
            else -> {
                val results: List<ScanResult> =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableArrayListExtra(BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT, ScanResult::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableArrayListExtra(BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT)
                    } ?: return
                TrailWake.onResults(context, results)
            }
        }
    }
}
