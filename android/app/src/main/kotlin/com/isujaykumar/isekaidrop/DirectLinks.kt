@file:Suppress("DEPRECATION")

package com.isujaykumar.isekaidrop

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkInfo
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pGroup
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.security.SecureRandom

/**
 * 0.10.0 "Fast direct": a phone-to-phone Wi-Fi link with no router hop.
 *
 * Hosting: Wi-Fi Direct group owner (Android 10+, 5 GHz asked first), else
 * a LocalOnlyHotspot (Android 8+, band chosen by the system).
 * Joining (Android 10+): Wi-Fi Direct connect with the group name and
 * password, else a WifiNetworkSpecifier request (the system asks the user
 * once) that this app's sockets are bound to.
 *
 * Everything runs on the main thread (all system callbacks use the main
 * looper); every MethodChannel result is answered exactly once. Passwords
 * are never logged. All state is torn down in [dispose].
 */
class DirectLinks(
    private val activity: Activity,
    private val channel: MethodChannel,
    private val onBindingReleased: () -> Unit,
) {
    companion object {
        const val PERMISSION_REQUEST = 4715
    }

    private val main = Handler(Looper.getMainLooper())
    private val wifi: WifiManager =
        activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val cm: ConnectivityManager =
        activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val p2p: WifiP2pManager? =
        activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private var p2pChannel: WifiP2pManager.Channel? = null

    // Hosting state
    private var hostingP2p = false
    private var p2pGroupUp = false
    private var lohs: WifiManager.LocalOnlyHotspotReservation? = null
    // Joining state
    private var joinedP2p = false
    private var p2pJoinUp = false
    private var specCallback: ConnectivityManager.NetworkCallback? = null
    @Volatile var boundNetwork: Network? = null
        private set
    private var receiver: BroadcastReceiver? = null
    private var pendingPermission: MethodChannel.Result? = null

    /** True while a direct link owns the process network binding, so the
     *  normal "Wi-Fi without internet" binding must not change it. */
    val ownsBinding: Boolean get() = boundNetwork != null

    private fun hasP2p(): Boolean =
        p2p != null && activity.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "caps" -> result.success(mapOf(
                    "sdk" to Build.VERSION.SDK_INT,
                    "p2p" to hasP2p(),
                    "canHost" to (Build.VERSION.SDK_INT >= 26),
                    "canJoin" to (Build.VERSION.SDK_INT >= 29),
                ))
                "permissionState" -> result.success(permissionState())
                "requestPermission" -> requestPermission(result)
                "openAppSettings" -> {
                    val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activity.packageName, null))
                    activity.startActivity(i)
                    result.success(true)
                }
                "host" -> host(call.argument<Boolean>("preferFiveGhz") ?: true, Once(result))
                "stopHost" -> { stopHost(); result.success(true) }
                "join" -> join(call, Once(result))
                "leave" -> { leave(); result.success(true) }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("no_permission", "not allowed", null)
        } catch (e: Exception) {
            result.error("error", e.javaClass.simpleName, null)
        }
    }

    /** Answers a MethodChannel result at most once. */
    private class Once(val r: MethodChannel.Result) {
        private var done = false
        val isDone get() = done
        fun ok(v: Any?) { if (!done) { done = true; r.success(v) } }
        fun fail(code: String) { if (!done) { done = true; r.error(code, code, null) } }
    }

    // ------------------------------------------------------------ permission

    private fun neededPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 33) arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun granted(): Boolean =
        if (Build.VERSION.SDK_INT >= 33)
            activity.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED
        else
            activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun locationOn(): Boolean {
        if (Build.VERSION.SDK_INT >= 33) return true // not needed with neverForLocation
        return try {
            val lm = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
            else (Settings.Secure.getInt(
                activity.contentResolver, Settings.Secure.LOCATION_MODE, 0) != 0)
        } catch (_: Exception) { true }
    }

    fun permissionState(): String = when {
        Build.VERSION.SDK_INT < 26 -> "unsupported"
        !granted() -> "denied"
        !locationOn() -> "location_off"
        !wifi.isWifiEnabled -> "wifi_off"
        else -> "granted"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (granted()) { result.success(permissionState()); return }
        if (pendingPermission != null) { result.error("busy", "Already asking", null); return }
        pendingPermission = result
        activity.requestPermissions(neededPermissions(), PERMISSION_REQUEST)
    }

    fun onPermissionResult() {
        val r = pendingPermission ?: return
        pendingPermission = null
        r.success(permissionState())
    }

    private fun precheck(): String? = when (permissionState()) {
        "granted" -> null
        "denied" -> "no_permission"
        "location_off" -> "location_off"
        "wifi_off" -> "wifi_off"
        else -> "unsupported"
    }

    // ---------------------------------------------------------------- events

    private fun event(name: String) {
        main.post { try { channel.invokeMethod("directEvent", name) } catch (_: Exception) {} }
    }

    private fun ensureReceiver() {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                val intent = i ?: return
                if (intent.action != WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION) return
                val ni = intent.getParcelableExtra<NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
                val connected = ni?.isConnected == true
                if (connected) return
                // Only report a loss after the link was confirmed up: the
                // first broadcast after registering is often "disconnected".
                if (hostingP2p && p2pGroupUp) {
                    hostingP2p = false; p2pGroupUp = false
                    event("host_stopped")
                }
                if (joinedP2p && p2pJoinUp) {
                    joinedP2p = false; p2pJoinUp = false
                    event("join_lost")
                }
            }
        }
        val f = IntentFilter(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        try {
            if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(r, f, Context.RECEIVER_NOT_EXPORTED)
            else activity.registerReceiver(r, f)
            receiver = r
        } catch (_: Exception) {
        }
    }

    private fun dropReceiverIfIdle() {
        if (hostingP2p || joinedP2p) return
        receiver?.let { try { activity.unregisterReceiver(it) } catch (_: Exception) {} }
        receiver = null
    }

    private fun p2pCh(): WifiP2pManager.Channel? {
        val m = p2p ?: return null
        p2pChannel?.let { return it }
        val ch = m.initialize(activity.applicationContext, Looper.getMainLooper()) {
            // The Wi-Fi Direct framework went away.
            p2pChannel = null
            if (hostingP2p) { hostingP2p = false; p2pGroupUp = false; event("host_stopped") }
            if (joinedP2p) { joinedP2p = false; p2pJoinUp = false; event("join_lost") }
        }
        p2pChannel = ch
        return ch
    }

    private fun p2pCode(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "unsupported"
        WifiP2pManager.BUSY -> "busy"
        else -> "error_$reason"
    }

    // ---------------------------------------------------------------- hosting

    private val alphabet = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    private val rnd = SecureRandom()
    private fun rand(n: Int) = String(CharArray(n) { alphabet[rnd.nextInt(alphabet.length)] })

    private fun host(preferFive: Boolean, out: Once) {
        precheck()?.let { out.fail(it); return }
        if (hostingP2p || lohs != null) stopHost()
        if (Build.VERSION.SDK_INT >= 29 && hasP2p()) {
            hostP2p(if (preferFive) WifiP2pConfig.GROUP_OWNER_BAND_5GHZ else WifiP2pConfig.GROUP_OWNER_BAND_AUTO,
                retriedBusy = false, out = out)
        } else {
            hostLohs(out, null)
        }
    }

    private fun hostP2p(band: Int, retriedBusy: Boolean, out: Once) {
        if (Build.VERSION.SDK_INT < 29) { hostLohs(out, null); return }
        val m = p2p ?: run { hostLohs(out, null); return }
        val ch = p2pCh() ?: run { hostLohs(out, null); return }
        val ssid = "DIRECT-" + rand(2) + "-IsekaiDrop"
        val pass = rand(10)
        val cfg = WifiP2pConfig.Builder()
            .setNetworkName(ssid)
            .setPassphrase(pass)
            .setGroupOperatingBand(band)
            .build()
        ensureReceiver()
        hostingP2p = true
        p2pGroupUp = false
        try {
            m.createGroup(ch, cfg, object : WifiP2pManager.ActionListener {
                override fun onSuccess() { waitForGroup(System.currentTimeMillis() + 12000, out) }
                override fun onFailure(reason: Int) {
                    hostingP2p = false
                    when {
                        reason == WifiP2pManager.BUSY && !retriedBusy -> {
                            // Usually a group left over from an earlier run.
                            m.removeGroup(ch, object : WifiP2pManager.ActionListener {
                                override fun onSuccess() { main.postDelayed({ hostP2p(band, true, out) }, 600) }
                                override fun onFailure(r: Int) { hostLohs(out, "busy") }
                            })
                        }
                        band == WifiP2pConfig.GROUP_OWNER_BAND_5GHZ ->
                            hostP2p(WifiP2pConfig.GROUP_OWNER_BAND_AUTO, retriedBusy, out)
                        else -> hostLohs(out, p2pCode(reason))
                    }
                }
            })
        } catch (e: SecurityException) {
            hostingP2p = false
            out.fail("no_permission")
        }
    }

    private fun waitForGroup(deadline: Long, out: Once) {
        val m = p2p ?: return
        val ch = p2pChannel ?: run { out.fail("stopped"); return }
        if (out.isDone) return
        try {
            m.requestGroupInfo(ch) { g: WifiP2pGroup? ->
                val ip = g?.`interface`?.let { ipv4Of(it) }
                if (g != null && g.isGroupOwner && ip != null && g.networkName != null && g.passphrase != null) {
                    p2pGroupUp = true
                    out.ok(mapOf(
                        "kind" to "wifi_direct",
                        "ssid" to g.networkName,
                        "pass" to g.passphrase,
                        "host" to ip,
                        "mhz" to (if (Build.VERSION.SDK_INT >= 29) g.frequency else 0),
                    ))
                } else if (System.currentTimeMillis() > deadline) {
                    stopP2pGroup()
                    out.fail(if (g == null) "timeout" else "no_address")
                } else {
                    main.postDelayed({ waitForGroup(deadline, out) }, 300)
                }
            }
        } catch (e: SecurityException) {
            stopP2pGroup()
            out.fail("no_permission")
        }
    }

    private fun lohsCode(reason: Int): String = when (reason) {
        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL -> "no_channel"
        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE -> "incompatible_mode"
        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED -> "tethering_disallowed"
        else -> "hotspot_failed_$reason"
    }

    private fun hostLohs(out: Once, p2pProblem: String?) {
        if (out.isDone) return
        if (Build.VERSION.SDK_INT < 26) { out.fail(p2pProblem ?: "unsupported"); return }
        dropReceiverIfIdle()
        val before = allIpv4().keys
        try {
            wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                    lohs = res
                    var ssid: String? = null
                    var pass: String? = null
                    if (Build.VERSION.SDK_INT >= 30) {
                        val c = res.softApConfiguration
                        ssid = c.ssid
                        pass = c.passphrase
                    } else {
                        val c = res.wifiConfiguration
                        ssid = c?.SSID
                        pass = c?.preSharedKey
                    }
                    ssid = ssid?.removeSurrounding("\"")
                    pass = pass?.removeSurrounding("\"")
                    if (ssid == null || pass == null) {
                        stopLohs(); out.fail("unsupported"); return
                    }
                    waitForHotspotIp(before, System.currentTimeMillis() + 6000, ssid, pass, p2pProblem, out)
                }
                override fun onStopped() {
                    if (lohs != null) { lohs = null; event("host_stopped") }
                }
                override fun onFailed(reason: Int) {
                    lohs = null
                    out.fail(p2pProblem ?: lohsCode(reason))
                }
            }, main)
        } catch (e: SecurityException) {
            out.fail("no_permission")
        } catch (e: IllegalStateException) {
            // Thrown when this app already holds a reservation.
            out.fail("busy")
        }
    }

    private fun waitForHotspotIp(before: Set<String>, deadline: Long, ssid: String, pass: String,
                                 p2pProblem: String?, out: Once) {
        if (out.isDone) return
        if (lohs == null) { out.fail("stopped"); return }
        val now = allIpv4()
        val fresh = now.entries.firstOrNull { it.key !in before && !it.value.startsWith("rmnet") && !it.value.startsWith("p2p") }
        if (fresh != null) {
            out.ok(mapOf(
                "kind" to "hotspot",
                "ssid" to ssid,
                "pass" to pass,
                "host" to fresh.key,
                "mhz" to 0,
                "note" to p2pProblem?.let { "wifi_direct_$it" },
            ))
        } else if (System.currentTimeMillis() > deadline) {
            stopLohs()
            out.fail("no_address")
        } else {
            main.postDelayed({ waitForHotspotIp(before, deadline, ssid, pass, p2pProblem, out) }, 250)
        }
    }

    private fun stopP2pGroup() {
        val m = p2p; val ch = p2pChannel
        hostingP2p = false; p2pGroupUp = false
        if (m != null && ch != null) {
            try { m.removeGroup(ch, null) } catch (_: Exception) {}
        }
        dropReceiverIfIdle()
    }

    private fun stopLohs() {
        val r = lohs
        lohs = null
        if (r != null && Build.VERSION.SDK_INT >= 26) {
            try { r.close() } catch (_: Exception) {}
        }
    }

    fun stopHost() {
        if (hostingP2p) stopP2pGroup()
        stopLohs()
    }

    // ---------------------------------------------------------------- joining

    private fun join(call: MethodCall, out: Once) {
        if (Build.VERSION.SDK_INT < 29) { out.fail("old_android"); return }
        precheck()?.let { out.fail(it); return }
        val kind = call.argument<String>("kind") ?: "hotspot"
        val ssid = call.argument<String>("ssid") ?: run { out.fail("bad_link"); return }
        val pass = call.argument<String>("pass") ?: run { out.fail("bad_link"); return }
        val host = call.argument<String>("host") ?: ""
        val mhz = call.argument<Int>("mhz") ?: 0
        val timeoutMs = (call.argument<Int>("timeoutMs") ?: 30000).coerceIn(5000, 120000)
        val deadline = System.currentTimeMillis() + timeoutMs
        leave()
        if (kind == "wifi_direct" && hasP2p()) {
            joinP2p(ssid, pass, host, mhz, deadline, out)
        } else {
            joinSpecifier(ssid, pass, deadline, out)
        }
    }

    private fun joinP2p(ssid: String, pass: String, host: String, mhz: Int, deadline: Long, out: Once) {
        if (Build.VERSION.SDK_INT < 29) { out.fail("old_android"); return }
        val m = p2p ?: run { joinSpecifier(ssid, pass, deadline, out); return }
        val ch = p2pCh() ?: run { joinSpecifier(ssid, pass, deadline, out); return }
        val b = WifiP2pConfig.Builder().setNetworkName(ssid).setPassphrase(pass)
        if (mhz > 0) b.setGroupOperatingFrequency(mhz) else b.setGroupOperatingBand(WifiP2pConfig.GROUP_OWNER_BAND_AUTO)
        val cfg = b.build()
        ensureReceiver()
        joinedP2p = true
        p2pJoinUp = false
        try {
            m.connect(ch, cfg, object : WifiP2pManager.ActionListener {
                override fun onSuccess() { waitForP2pIp(host, deadline, out) }
                override fun onFailure(reason: Int) {
                    joinedP2p = false
                    dropReceiverIfIdle()
                    if (mhz > 0 && reason != WifiP2pManager.P2P_UNSUPPORTED) {
                        // Retry letting the system scan every band.
                        joinP2p(ssid, pass, host, 0, deadline, out)
                    } else {
                        // A Wi-Fi Direct group is also a normal WPA2 network.
                        joinSpecifier(ssid, pass, deadline, out)
                    }
                }
            })
        } catch (e: SecurityException) {
            joinedP2p = false
            out.fail("no_permission")
        }
    }

    private fun sameSubnet24(a: String, b: String): Boolean {
        if (b.isEmpty()) return true
        val x = a.split('.'); val y = b.split('.')
        return x.size == 4 && y.size == 4 && x[0] == y[0] && x[1] == y[1] && x[2] == y[2]
    }

    private fun waitForP2pIp(host: String, deadline: Long, out: Once) {
        if (out.isDone) return
        if (!joinedP2p) { out.fail("stopped"); return }
        val hit = allIpv4().entries.firstOrNull { it.value.startsWith("p2p") && sameSubnet24(it.key, host) && it.key != host }
        if (hit != null) {
            p2pJoinUp = true
            out.ok(mapOf("localIp" to hit.key, "iface" to hit.value))
        } else if (System.currentTimeMillis() > deadline) {
            leaveP2p()
            out.fail("timeout")
        } else {
            main.postDelayed({ waitForP2pIp(host, deadline, out) }, 300)
        }
    }

    private fun joinSpecifier(ssid: String, pass: String, deadline: Long, out: Once) {
        if (Build.VERSION.SDK_INT < 29) { out.fail("old_android"); return }
        if (out.isDone) return
        val left = (deadline - System.currentTimeMillis()).toInt()
        if (left < 3000) { out.fail("timeout"); return }
        val spec = WifiNetworkSpecifier.Builder().setSsid(ssid).setWpa2Passphrase(pass).build()
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(spec)
            .build()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(n: Network) {
                main.post {
                    if (specCallback !== this) return@post
                    try { cm.bindProcessToNetwork(n) } catch (_: Exception) {}
                    boundNetwork = n
                    val lp = try { cm.getLinkProperties(n) } catch (_: Exception) { null }
                    val ip = lp?.linkAddresses?.map { it.address }?.filterIsInstance<Inet4Address>()?.firstOrNull()?.hostAddress
                    var mbps: Int? = null
                    var freq: Int? = null
                    if (Build.VERSION.SDK_INT >= 31) {
                        val wi = try { cm.getNetworkCapabilities(n)?.transportInfo as? WifiInfo } catch (_: Exception) { null }
                        if (wi != null) { mbps = wi.linkSpeed.takeIf { it > 0 }; freq = wi.frequency.takeIf { it > 0 } }
                    }
                    out.ok(mapOf("localIp" to ip, "mbps" to mbps, "mhz" to freq, "iface" to lp?.interfaceName))
                }
            }
            override fun onUnavailable() {
                main.post {
                    if (specCallback !== this) return@post
                    specCallback = null
                    out.fail(if (System.currentTimeMillis() >= deadline - 500) "timeout" else "declined")
                }
            }
            override fun onLost(n: Network) {
                main.post {
                    if (specCallback !== this) return@post
                    val wasUp = boundNetwork != null
                    unbindSpecifier()
                    if (wasUp) event("join_lost") else out.fail("stopped")
                }
            }
        }
        specCallback = cb
        try {
            cm.requestNetwork(req, cb, left)
        } catch (e: SecurityException) {
            specCallback = null
            out.fail("no_permission")
        }
    }

    private fun unbindSpecifier() {
        val cb = specCallback
        specCallback = null
        if (boundNetwork != null) {
            try { cm.bindProcessToNetwork(null) } catch (_: Exception) {}
            boundNetwork = null
            onBindingReleased()
        }
        cb?.let { try { cm.unregisterNetworkCallback(it) } catch (_: Exception) {} }
    }

    private fun leaveP2p() {
        val m = p2p; val ch = p2pChannel
        val was = joinedP2p
        joinedP2p = false; p2pJoinUp = false
        if (was && m != null && ch != null) {
            try { m.cancelConnect(ch, null) } catch (_: Exception) {}
            try { m.removeGroup(ch, null) } catch (_: Exception) {}
        }
        dropReceiverIfIdle()
    }

    fun leave() {
        leaveP2p()
        unbindSpecifier()
    }

    fun dispose() {
        try { leave() } catch (_: Exception) {}
        try { stopHost() } catch (_: Exception) {}
        receiver?.let { try { activity.unregisterReceiver(it) } catch (_: Exception) {} }
        receiver = null
        pendingPermission?.let { try { it.success("denied") } catch (_: Exception) {} }
        pendingPermission = null
    }

    // --------------------------------------------------------------- helpers

    private fun ipv4Of(iface: String): String? = try {
        NetworkInterface.getByName(iface)?.inetAddresses?.toList()
            ?.filterIsInstance<Inet4Address>()?.firstOrNull()?.hostAddress
    } catch (_: Exception) { null }

    /** IPv4 address -> interface name, for interfaces that are up. */
    private fun allIpv4(): Map<String, String> {
        val out = mutableMapOf<String, String>()
        try {
            for (ni in NetworkInterface.getNetworkInterfaces()?.toList() ?: emptyList()) {
                if (!ni.isUp || ni.isLoopback) continue
                for (a in ni.inetAddresses.toList()) {
                    if (a is Inet4Address) a.hostAddress?.let { out[it] = ni.name }
                }
            }
        } catch (_: Exception) {
        }
        return out
    }
}
