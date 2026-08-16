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
                "getTorStatus" -> result.success(TorRuntimeManager.status(applicationContext))
                "start" -> {
                    try {
                        TorRuntimeManager.startIfEmbedded(applicationContext)
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
        super.onDestroy()
        applicationContext.stopService(
            Intent(applicationContext, RetroShareServiceAndroid::class.java),
        )
    }
}
