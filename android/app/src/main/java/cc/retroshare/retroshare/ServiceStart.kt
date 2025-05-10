package cc.retroshare.retroshare

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ServiceStart : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.i("ServiceStart", "onReceive() Starting Service")

        // Vérification si le service est déjà en cours d'exécution
        if (isServiceRunning(context, RetroShareServiceAndroid::class.java)) {
            Log.i("ServiceStart", "Service is already running.")
        } else {
            Log.i("ServiceStart", "Service not running, starting it.")
            RetroShareServiceAndroid.start(context)
        }
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
