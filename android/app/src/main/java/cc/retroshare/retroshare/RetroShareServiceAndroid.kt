package cc.retroshare.retroshare

import android.annotation.SuppressLint
import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.retroshare.service.RetroShareServiceAndroid as RsService

class RetroShareServiceAndroid : RsService() {

    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val ACTION_SHUTDOWN = "SHUTDOWN"
        const val CHANNEL_ID = "cc.retroshare.retroshare/retroshare"
        private const val WAKELOCK_TAG = "RetroShareServiceAndroid:Wakelock"

        private val JSON_API_PORT_KEY = RsService::class.java.canonicalName + "/JSON_API_PORT_KEY"
        private val JSON_API_BIND_ADDRESS_KEY =
            RsService::class.java.canonicalName + "/JSON_API_BIND_ADDRESS_KEY"

        private var rsInitialized = false

        fun start(
            ctx: Context,
            jsonApiPort: Int = DEFAULT_JSON_API_PORT,
            jsonApiBindAddress: String = DEFAULT_JSON_API_BINDING_ADDRESS,
        ) {
            val intent = Intent(ctx, RetroShareServiceAndroid::class.java)
            intent.putExtra(JSON_API_PORT_KEY, jsonApiPort)
            intent.putExtra(JSON_API_BIND_ADDRESS_KEY, jsonApiBindAddress)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
        }

        fun stop(ctx: Context) {
            val intent = Intent(ctx, RetroShareServiceAndroid::class.java)
            ctx.stopService(intent)
        }

        fun isRunning(ctx: Context): Boolean {
            val manager = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            for (service in manager.getRunningServices(Int.MAX_VALUE)) {
                if (RetroShareServiceAndroid::class.java.name == service.service.className) {
                    return true
                }
            }
            return false
        }
    }

    @SuppressLint("WakelockTimeout")
    override fun onCreate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RetroShare Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RetroShare")
            .setContentText("RetroShare works in the background.")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .build()

        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG)
            .apply {
                setReferenceCounted(false)
                acquire()
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(1, notification)
        }

        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_SHUTDOWN) {
            @Suppress("DEPRECATION")
            stopForeground(true)
            stopSelf()
        } else if (!rsInitialized) {
            rsInitialized = true
            super.onStartCommand(intent, flags, startId)
        }
        // Android 12+ may not recreate a foreground service while the app is in
        // the background. Let the visible activity explicitly start it instead.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        rsInitialized = false
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()

        // libretroshare keeps process-wide native singletons (including
        // AuthSSL) after the Android Service is destroyed. This service runs
        // in its own :retroshare process so terminating that now-empty process
        // is required to unlock a different location safely.
        if (android.app.Application.getProcessName().endsWith(":retroshare")) {
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)

}
