package com.icyanstudio.sync

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Base64
import kotlin.math.min
import kotlin.math.roundToInt
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "sync.notifications"
    private val notificationChannelId = "sync_messages"
    private val notificationRequestCode = 4041
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPushPermission" -> requestPushPermission(result)
                "getPushToken" -> result.success(null)
                "showLocalNotification" -> showLocalNotification(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPushPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }

        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationRequestCode,
        )
    }

    private fun showLocalNotification(args: Any?, result: MethodChannel.Result) {
        val map = args as? Map<*, *> ?: run {
            result.error("invalid_args", "Expected title/body arguments", null)
            return
        }

        val title = (map["title"] as? String)?.trim().orEmpty()
        val body = (map["body"] as? String)?.trim().orEmpty()
        val avatarBase64 = (map["avatarBase64"] as? String)?.trim().orEmpty()
        if (title.isEmpty() && body.isEmpty()) {
            result.success(null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                result.success(null)
                return
            }
        }

        val builder = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        if (avatarBase64.isNotEmpty()) {
            try {
                val bitmap = decodeCenteredAvatarLargeIcon(avatarBase64)
                if (bitmap != null) {
                    builder.setLargeIcon(bitmap)
                }
            } catch (_: IllegalArgumentException) {
                // Ignore malformed base64 avatar payloads.
            }
        }

        val notification = builder.build()

        NotificationManagerCompat.from(this).notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
        result.success(null)
    }

    private fun decodeCenteredAvatarLargeIcon(avatarBase64: String): Bitmap? {
        val bytes = Base64.decode(avatarBase64, Base64.DEFAULT)
        val raw = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val squareSize = min(raw.width, raw.height)
        if (squareSize <= 0) {
            return null
        }

        val left = (raw.width - squareSize) / 2
        val top = (raw.height - squareSize) / 2
        val square = Bitmap.createBitmap(raw, left, top, squareSize, squareSize)

        val targetPx = (56f * resources.displayMetrics.density).roundToInt().coerceAtLeast(64)
        return Bitmap.createScaledBitmap(square, targetPx, targetPx, true)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            notificationChannelId,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        )
        manager.createNotificationChannel(channel)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequestCode) {
            return
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
    }
}
