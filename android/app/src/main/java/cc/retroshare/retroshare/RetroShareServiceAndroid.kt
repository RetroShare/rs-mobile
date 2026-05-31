package cc.retroshare.retroshare

import android.annotation.SuppressLint
import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import org.retroshare.service.RetroShareServiceAndroid as RsService

class RetroShareServiceAndroid : RsService() {

    companion object {
        const val ACTION_SHUTDOWN = "SHUTDOWN"
        const val CHANNEL_ID = "cc.retroshare.retroshare/retroshare"
        private const val WAKELOCK_TAG = "RetroShareServiceAndroid:Wakelock"
        private const val TAG = "RetroShareServiceAndroid"

        private val JSON_API_PORT_KEY = RsService::class.java.canonicalName + "/JSON_API_PORT_KEY"
        private val JSON_API_BIND_ADDRESS_KEY =
            RsService::class.java.canonicalName + "/JSON_API_BIND_ADDRESS_KEY"

        private var rsInitialized = false

        fun start(
            ctx: Context,
            jsonApiPort: Int = 9092,
            jsonApiBindAddress: String = "127.0.0.1",
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
            intent.action = ACTION_SHUTDOWN
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
        }

        fun isRunning(ctx: Context): Boolean {
            val manager = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
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
        Log.i(TAG, "Service onCreate")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RetroShare Service Channel",
                NotificationManager.IMPORTANCE_LOW,
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RetroShare")
            .setContentText("RetroShare service is active")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        (getSystemService(Context.POWER_SERVICE) as PowerManager)
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
        val workIntent = intent ?: Intent(this, RetroShareServiceAndroid::class.java)
        
        if (workIntent.action == ACTION_SHUTDOWN) {
            Log.i(TAG, "Action Shutdown received")
            @Suppress("DEPRECATION")
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        } else if (!rsInitialized) {
            Log.i(TAG, "Initializing Native Core")
            rsInitialized = true
            
            // Ensure required extras are present for the base class
            if (!workIntent.hasExtra(JSON_API_PORT_KEY)) {
                workIntent.putExtra(JSON_API_PORT_KEY, 9092)
            }
            if (!workIntent.hasExtra(JSON_API_BIND_ADDRESS_KEY)) {
                workIntent.putExtra(JSON_API_BIND_ADDRESS_KEY, "127.0.0.1")
            }
            
            super.onStartCommand(workIntent, flags, startId)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "Service onDestroy")
        rsInitialized = false
        (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG)
            .apply { if (isHeld) release() }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)

    override fun onTaskRemoved(rootIntent: Intent) {
        val restartIntent = Intent(applicationContext, RetroShareServiceAndroid::class.java)
            .also { it.setPackage(packageName) }
        val pendingIntent = PendingIntent.getService(
            this,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE,
        )
        (applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + 1000, pendingIntent)
    }
}
