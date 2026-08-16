package cc.retroshare.retroshare

import android.content.Context
import android.content.Intent
import org.torproject.jni.TorService
import java.net.InetSocketAddress
import java.net.Socket

/** Owns the optional in-process Tor runtime. RetroShare itself remains a
 * separate service and talks to Tor over loopback, just like on desktop. */
object TorRuntimeManager {
    const val MODE_DISABLED = "disabled"
    const val MODE_EMBEDDED = "embedded"
    const val MODE_EXTERNAL = "external"

    private const val PREFS = "tor_runtime"
    private const val KEY_MODE = "mode"
    private const val KEY_HOST = "host"
    private const val KEY_SOCKS_PORT = "socks_port"
    private const val KEY_CONTROL_PORT = "control_port"
    private const val EMBEDDED_SOCKS_PORT = 39050
    private const val EMBEDDED_CONTROL_PORT = 39051

    fun configure(context: Context, mode: String, host: String, socksPort: Int, controlPort: Int) {
        require(mode in setOf(MODE_DISABLED, MODE_EMBEDDED, MODE_EXTERNAL)) { "Unknown Tor mode" }
        require(socksPort in 1..65535 && controlPort in 1..65535) { "Invalid Tor port" }
        require(host.isNotBlank()) { "Tor host cannot be empty" }

        if (mode != MODE_EMBEDDED) stopEmbedded(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_MODE, mode)
            .putString(KEY_HOST, if (mode == MODE_EMBEDDED) "127.0.0.1" else host)
            .putInt(KEY_SOCKS_PORT, if (mode == MODE_EMBEDDED) EMBEDDED_SOCKS_PORT else socksPort)
            .putInt(KEY_CONTROL_PORT, if (mode == MODE_EMBEDDED) EMBEDDED_CONTROL_PORT else controlPort)
            .apply()
        if (mode == MODE_EMBEDDED) startIfEmbedded(context)
    }

    fun configuration(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val mode = prefs.getString(KEY_MODE, MODE_DISABLED) ?: MODE_DISABLED
        return mapOf(
            "mode" to mode,
            "host" to prefs.getString(KEY_HOST, "127.0.0.1").orEmpty(),
            "socksPort" to prefs.getInt(KEY_SOCKS_PORT, if (mode == MODE_EMBEDDED) EMBEDDED_SOCKS_PORT else 9050),
            "controlPort" to prefs.getInt(KEY_CONTROL_PORT, if (mode == MODE_EMBEDDED) EMBEDDED_CONTROL_PORT else 9051),
        )
    }

    fun startIfEmbedded(context: Context) {
        if (configuration(context)["mode"] != MODE_EMBEDDED) return
        val torrc = TorService.getTorrc(context)
        torrc.parentFile?.mkdirs()
        torrc.writeText(
            "SocksPort 127.0.0.1:$EMBEDDED_SOCKS_PORT\n" +
                "ControlPort 127.0.0.1:$EMBEDDED_CONTROL_PORT\n" +
                "CookieAuthentication 0\n" +
                "ClientOnly 1\n",
        )
        context.startService(Intent(context, TorService::class.java).setAction(TorService.ACTION_START))
    }

    fun stopEmbedded(context: Context) {
        context.stopService(Intent(context, TorService::class.java))
    }

    fun restartIfEmbedded(context: Context) {
        if (configuration(context)["mode"] != MODE_EMBEDDED) return
        stopEmbedded(context)
        startIfEmbedded(context)
    }

    fun status(context: Context): Map<String, Any> {
        val config = configuration(context)
        val host = config["host"] as String
        val socksPort = config["socksPort"] as Int
        return config + mapOf("reachable" to isReachable(host, socksPort))
    }

    private fun isReachable(host: String, port: Int): Boolean = try {
        Socket().use { it.connect(InetSocketAddress(host, port), 350) }
        true
    } catch (_: Exception) {
        false
    }
}
