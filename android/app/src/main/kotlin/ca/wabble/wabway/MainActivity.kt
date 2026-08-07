package ca.wabble.wabway

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        var locationSharingChannel: MethodChannel? = null
        private var linksChannel: MethodChannel? = null

        // Geolocator internal constants (GeolocatorLocationService.java)
        private const val GEO_NOTIFICATION_ID = 75415
        private const val GEO_CHANNEL_ID = "geolocator_channel_01"

        const val STOP_ACTION = "ca.wabble.wabway.STOP_LOCATION_SHARING"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Installer channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ca.wabble.wabway/installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGS", "path required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = File(path)
                            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                FileProvider.getUriForFile(
                                    this, "${packageName}.fileprovider", file,
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                Uri.fromFile(file)
                            }
                            val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                                data = uri
                                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Deep links channel ───────────────────────────────────────────────
        linksChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ca.wabble.wabway/links",
        )
        linksChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(intent?.dataString)
                else -> result.notImplemented()
            }
        }

        // ── Location sharing channel ─────────────────────────────────────────
        locationSharingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ca.wabble.wabway/location_sharing",
        )
        locationSharingChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "addStopAction" -> {
                    addStopActionToNotification()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun addStopActionToNotification() {
        val stopIntent = Intent(this, StopLocationReceiver::class.java).apply {
            action = STOP_ACTION
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(this, 0, stopIntent, piFlags)

        val iconId = resources.getIdentifier("ic_launcher", "mipmap", packageName)

        val notification = NotificationCompat.Builder(this, GEO_CHANNEL_ID)
            .setSmallIcon(iconId)
            .setContentTitle("WabWay location sharing")
            .setContentText("Sharing your location with your crew")
            .setOngoing(true)
            .addAction(0, "Stop sharing", pendingIntent)
            .build()

        NotificationManagerCompat.from(this).notify(GEO_NOTIFICATION_ID, notification)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val url = intent.dataString
        if (url != null) {
            linksChannel?.invokeMethod("onNewLink", url)
        }
    }

    override fun onDestroy() {
        locationSharingChannel = null
        linksChannel = null
        super.onDestroy()
    }
}
