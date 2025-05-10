package cc.retroshare.retroshare

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log


class ServiceRestart : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.i("ServiceRestart", "onReceive() Restarting Service")
        
        if (isServiceRunning(context, RetroShareServiceAndroid::class.java)) {
            Log.i("ServiceRestart", "Service is running, stopping it before restart.")
            RetroShareServiceAndroid.stop(context)
        } else {
            Log.i("ServiceRestart", "Service not running, skipping stop.")
        }

        RetroShareServiceAndroid.start(context)
    }

    private fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningServices = activityManager.getRunningServices(Int.MAX_VALUE)

        for (service in runningServices) {
            if (service.service.className == serviceClass.name) {
                return true
            }
        }
        return false
    }
}