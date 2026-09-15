package cc.retroshare.retroshare

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "cc.retroshare.retroshare/retroshare"
    private var activityResumed = false

    override fun onResume() {
        super.onResume()
        activityResumed = true
        // Recover a backend that Android stopped while the UI process remained
        // cached. Foreground-service starts are allowed while this activity is
        // visible.
        if (!RetroShareServiceAndroid.isRunning(applicationContext)) {
            try {
                RetroShareServiceAndroid.start(applicationContext)
            } catch (_: Exception) {
                // Flutter's startup flow reports and retries visible failures.
            }
        }
    }

    override fun onPause() {
        activityResumed = false
        super.onPause()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (!activityResumed) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
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

}
