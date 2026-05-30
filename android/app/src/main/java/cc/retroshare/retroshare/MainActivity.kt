package cc.retroshare.retroshare

import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "cc.retroshare.retroshare/retroshare"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        RetroShareServiceAndroid.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stop" -> {
                    RetroShareServiceAndroid.stop(applicationContext)
                    result.success(true)
                }
                "restart" -> {
                    try {
                        RetroShareServiceAndroid.stop(applicationContext)
                        RetroShareServiceAndroid.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESTART_FAILED", e.message, null)
                    }
                }
                "isRunning" -> {
                    result.success(RetroShareServiceAndroid.isRunning(applicationContext))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        applicationContext.stopService(
            Intent(applicationContext, RetroShareServiceAndroid::class.java),
        )
    }
}
