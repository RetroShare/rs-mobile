package cc.retroshare.retroshare

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "cc.retroshare.retroshare/retroshare"
    private val torStatusExecutor = Executors.newSingleThreadExecutor()
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
                "getTorConfiguration" -> result.success(TorRuntimeManager.configuration(applicationContext))
                "setTorConfiguration" -> {
                    val mode = call.argument<String>("mode") ?: TorRuntimeManager.MODE_DISABLED
                    val host = call.argument<String>("host") ?: "127.0.0.1"
                    val socksPort = call.argument<Int>("socksPort") ?: 9050
                    val controlPort = call.argument<Int>("controlPort") ?: 9051
                    try {
                        TorRuntimeManager.configure(applicationContext, mode, host, socksPort, controlPort)
                        result.success(TorRuntimeManager.configuration(applicationContext))
                    } catch (e: Exception) {
                        result.error("TOR_CONFIG_FAILED", e.message, null)
                    }
                }
                "getTorStatus" -> torStatusExecutor.execute {
                    try {
                        val status = TorRuntimeManager.status(applicationContext)
                        runOnUiThread { result.success(status) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("TOR_STATUS_FAILED", error.message, null)
                        }
                    }
                }
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
                    TorRuntimeManager.stopEmbedded(applicationContext)
                    result.success(true)
                }
                "stopBackend" -> {
                    // Account switching must not restart the shared Tor
                    // runtime. Android may reject restarting Tor once the app
                    // is backgrounded, and all hidden locations can use the
                    // same embedded Tor instance.
                    RetroShareServiceAndroid.stop(applicationContext)
                    result.success(true)
                }
                "startTor" -> {
                    try {
                        TorRuntimeManager.startIfEmbedded(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TOR_START_FAILED", e.message, null)
                    }
                }
                "stopTor" -> {
                    TorRuntimeManager.stopEmbedded(applicationContext)
                    result.success(true)
                }
                "isHiddenLocation" -> {
                    val locationId = call.argument<String>("locationId").orEmpty()
                    result.success(TorRuntimeManager.isHiddenLocation(applicationContext, locationId))
                }
                "restart" -> {
                    try {
                        RetroShareServiceAndroid.stop(applicationContext)
                        TorRuntimeManager.restartIfEmbedded(applicationContext)
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
        torStatusExecutor.shutdownNow()
        super.onDestroy()
    }
}
