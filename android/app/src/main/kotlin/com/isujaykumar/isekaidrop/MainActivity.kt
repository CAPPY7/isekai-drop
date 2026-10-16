package com.isujaykumar.isekaidrop

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import java.net.Inet4Address
import android.net.wifi.WifiInfo
import android.provider.DocumentsContract
import android.provider.Settings
import android.view.WindowManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

/**
 * Small native helpers for Isekai Drop on Android:
 *  - system file picker returning content URIs (no copy into memory),
 *  - read access through a file descriptor so Dart can stream the file,
 *  - saving verified received files into Downloads/Isekai Drop,
 *  - a Wi-Fi multicast lock so device discovery packets are received,
 *  - folder picking (structure kept), connection info for Diagnostics,
 *  - an app-made local-only hotspot (no internet) for router-free transfers,
 *  - keeping the screen on while a transfer runs.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "isekai_drop/android"
    private val pickRequest = 4711
    private val folderRequest = 4712
    private val permRequest = 4713
    private var pendingFolder: MethodChannel.Result? = null
    private var pendingPerm: MethodChannel.Result? = null

    // Audit #6: Android 9 and older have no MediaStore.Downloads, so writing
    // to the public Downloads folder needs WRITE_EXTERNAL_STORAGE (declared
    // with maxSdkVersion=28, never requested on Android 10+).
    private val legacyRequest = 4714
    private var pendingLegacy: MethodChannel.Result? = null

    private fun legacyGranted(): Boolean =
        Build.VERSION.SDK_INT >= 29 ||
            checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun ensureLegacyStorage(result: MethodChannel.Result) {
        if (legacyGranted()) { result.success(true); return }
        if (pendingLegacy != null) { result.error("busy", "Already asking", null); return }
        pendingLegacy = result
        requestPermissions(arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE), legacyRequest)
    }

    /** Public Downloads/Isekai Drop when allowed, else the app's own folder. */
    @Suppress("DEPRECATION")
    private fun legacyBase(): File =
        if (legacyGranted()) File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Isekai Drop")
        else File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "Isekai Drop")
    private var hotspot: WifiManager.LocalOnlyHotspotReservation? = null
    private var channel: MethodChannel? = null
    private var nsdReg: NsdManager.RegistrationListener? = null
    private var nsdDisc: NsdManager.DiscoveryListener? = null
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false
    private var pendingPick: MethodChannel.Result? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFiles" -> pickFiles(result)
                    "openFd" -> openFd(call.argument<String>("uri")!!, result)
                    "closeFd" -> {
                        try {
                            ParcelFileDescriptor.adoptFd(call.argument<Int>("fd")!!).close()
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    "ensureLegacyStorage" -> ensureLegacyStorage(result)
                    "exportToDownloads" -> exportToDownloads(
                        call.argument<String>("path")!!,
                        call.argument<String>("name")!!,
                        call.argument<String>("sub") ?: "",
                        result,
                    )
                    "pickFolder" -> pickFolder(result)
                    "nsdStart" -> {
                        @Suppress("UNCHECKED_CAST")
                        nsdStart(
                            call.argument<String>("name")!!,
                            call.argument<Int>("port")!!,
                            call.argument<Map<String, String>>("txt") ?: emptyMap(),
                            call.argument<Boolean>("advertise") ?: true,
                        )
                        result.success(null)
                    }
                    "nsdStop" -> {
                        nsdStop()
                        result.success(null)
                    }
                    "folderExists" -> folderExists(call.argument<String>("name")!!, result)
                    "networkInfo" -> result.success(networkInfo())
                    "hotspotPermission" -> result.success(hotspotPermissionState())
                    "requestHotspotPermission" -> requestHotspotPermission(result)
                    "startHotspot" -> startHotspot(result)
                    "stopHotspot" -> {
                        stopHotspot()
        nsdStop()
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        if (call.argument<Boolean>("on") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "acquireMulticastLock" -> {
                        try {
                            if (multicastLock == null) {
                                val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                                multicastLock = wifi.createMulticastLock("isekai-drop-discovery").apply {
                                    setReferenceCounted(false)
                                    acquire()
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            multicastLock?.release()
        } catch (_: Exception) {
        }
        stopHotspot()
        super.onDestroy()
    }

    private fun pickFiles(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, pickRequest)
    }

    @Deprecated("Uses the platform activity result API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == folderRequest) {
            onFolderResult(resultCode, data)
            return
        }
        if (requestCode != pickRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        } ?: data.data?.let { uris.add(it) }
        val out = uris.map { uri ->
            var name = "file"
            var size: Long = -1
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0 && !c.isNull(n)) name = c.getString(n)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
            mapOf("uri" to uri.toString(), "name" to name, "size" to size)
        }
        result.success(out)
    }

    private fun openFd(uri: String, result: MethodChannel.Result) {
        try {
            val pfd = contentResolver.openFileDescriptor(Uri.parse(uri), "r")
            if (pfd == null) {
                result.error("open_failed", "Could not open file", null)
                return
            }
            result.success(pfd.detachFd())
        } catch (e: Exception) {
            result.error("open_failed", "Could not open file", null)
        }
    }

    private fun exportToDownloads(path: String, name: String, sub: String, result: MethodChannel.Result) {
        io.execute {
            val src = File(path)
            try {
                val where: String
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, name)
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop" + (if (sub.isEmpty()) "" else "/$sub"))
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("insert failed")
                    try {
                        contentResolver.openOutputStream(uri)!!.use { out ->
                            FileInputStream(src).use { it.copyTo(out, 1 shl 20) }
                        }
                        values.clear()
                        values.put(MediaStore.Downloads.IS_PENDING, 0)
                        contentResolver.update(uri, values, null, null)
                    } catch (e: Exception) {
                        contentResolver.delete(uri, null, null)
                        throw e
                    }
                    where = "Downloads/Isekai Drop/" + (if (sub.isEmpty()) "" else "$sub/") + name
                } else {
                    val base = legacyBase()
                    val dir = if (sub.isEmpty()) base else File(base, sub)
                    if (!dir.canonicalPath.startsWith(base.canonicalPath)) throw SecurityException("unsafe path")
                    dir.mkdirs()
                    var target = File(dir, name)
                    var i = 1
                    val dot = name.lastIndexOf('.')
                    while (!target.createNewFile()) {
                        val n = if (dot > 0) name.substring(0, dot) + " ($i)" + name.substring(dot) else "$name ($i)"
                        target = File(dir, n)
                        i++
                    }
                    FileInputStream(src).use { input -> target.outputStream().use { input.copyTo(it, 1 shl 20) } }
                    android.media.MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), null, null)
                    where = target.absolutePath
                }
                src.delete()
                runOnUiThread { result.success(where) }
            } catch (e: Exception) {
                src.delete()
                runOnUiThread { result.error("save_failed", "Could not save file", null) }
            }
        }
    }

    // ------------------------------------------------------------ folders

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingFolder != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        pendingFolder = result
        @Suppress("DEPRECATION")
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), folderRequest)
    }

    private fun onFolderResult(resultCode: Int, data: Intent?) {
        val result = pendingFolder ?: return
        pendingFolder = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return
        }
        io.execute {
            try {
                val out = mutableListOf<Map<String, Any?>>()
                val rootId = DocumentsContract.getTreeDocumentId(tree)
                var rootName = "Folder"
                contentResolver.query(
                    DocumentsContract.buildDocumentUriUsingTree(tree, rootId),
                    arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null,
                )?.use { c -> if (c.moveToFirst() && !c.isNull(0)) rootName = c.getString(0) }
                walk(tree, rootId, rootName, out, 0)
                runOnUiThread { result.success(mapOf("name" to rootName, "files" to out)) }
            } catch (e: Exception) {
                runOnUiThread { result.error("folder_failed", "Could not read folder", null) }
            }
        }
    }

    private fun walk(tree: Uri, docId: String, rel: String, out: MutableList<Map<String, Any?>>, depth: Int) {
        if (depth > 32 || out.size > 20000) return
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        val cols = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        contentResolver.query(children, cols, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: "file"
                val mime = c.getString(2) ?: ""
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(tree, id, "$rel/$name", out, depth + 1)
                } else {
                    val size = if (c.isNull(3)) -1L else c.getLong(3)
                    out.add(mapOf(
                        "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                        "name" to name,
                        "rel" to "$rel/$name",
                        "size" to size,
                    ))
                }
            }
        }
    }

    /** True if this app already saved something under Downloads/Isekai Drop/<name>. */
    private fun folderExists(name: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                val prefix = Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop/" + name + "/"
                contentResolver.query(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    arrayOf(MediaStore.Downloads._ID),
                    MediaStore.Downloads.RELATIVE_PATH + " LIKE ?",
                    arrayOf(prefix.replace("%", "\\%").replace("_", "\\_") + "%"),
                    null,
                ).use { c -> result.success((c?.count ?: 0) > 0) }
            } else {
                val dir = File(legacyBase(), name)
                result.success(dir.exists())
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // ------------------------------------------------------ diagnostics

    /** Connection type and Wi-Fi link speed. No network name, no addresses. */
    private fun networkInfo(): Map<String, Any?> {
        val out = mutableMapOf<String, Any?>("transport" to "none", "hotspotByApp" to (hotspot != null))
        try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.getNetworkCapabilities(cm.activeNetwork)
            if (caps != null) {
                out["transport"] = when {
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                    else -> "other"
                }
            }
            val info: WifiInfo? = if (Build.VERSION.SDK_INT >= 31) {
                caps?.transportInfo as? WifiInfo
            } else {
                @Suppress("DEPRECATION")
                (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager).connectionInfo
            }
            if (info != null && info.linkSpeed > 0) {
                out["linkMbps"] = info.linkSpeed
                out["frequencyMhz"] = info.frequency
            }
        } catch (_: Exception) {
        }
        return out
    }

    // ---------------------------------------------------- local-only hotspot

    private fun hotspotPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        }

    private fun locationOn(): Boolean {
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= 28) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getInt(contentResolver, Settings.Secure.LOCATION_MODE, 0) != 0
        }
    }

    /** "granted", "needed", "location_off" (Android 12 and older only). */
    private fun hotspotPermissionState(): String {
        val ok = hotspotPermissions().take(1).all {
            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
        if (!ok) return "needed"
        if (Build.VERSION.SDK_INT < 33 && !locationOn()) return "location_off"
        return "granted"
    }

    private fun requestHotspotPermission(result: MethodChannel.Result) {
        if (pendingPerm != null) {
            result.error("busy", "Already asking", null)
            return
        }
        pendingPerm = result
        requestPermissions(hotspotPermissions(), permRequest)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == legacyRequest) {
            val r = pendingLegacy ?: return
            pendingLegacy = null
            r.success(legacyGranted())
            return
        }
        if (requestCode != permRequest) return
        val r = pendingPerm ?: return
        pendingPerm = null
        r.success(hotspotPermissionState())
    }

    private fun startHotspot(result: MethodChannel.Result) {
        if (hotspot != null) {
            result.success(hotspotDetails(hotspot!!))
            return
        }
        try {
            val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            var answered = false
            wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    hotspot = reservation
                    if (!answered) {
                        answered = true
                        result.success(hotspotDetails(reservation))
                    }
                }

                override fun onStopped() {
                    hotspot = null
                }

                override fun onFailed(reason: Int) {
                    hotspot = null
                    if (!answered) {
                        answered = true
                        val code = when (reason) {
                            ERROR_NO_CHANNEL -> "no_channel"
                            ERROR_INCOMPATIBLE_MODE -> "incompatible_mode"
                            ERROR_TETHERING_DISALLOWED -> "tethering_disallowed"
                            else -> "generic"
                        }
                        result.error(code, "Hotspot could not start", null)
                    }
                }
            }, null)
        } catch (e: SecurityException) {
            result.error("permission", "Permission missing", null)
        } catch (e: Exception) {
            result.error("generic", "Hotspot could not start", null)
        }
    }

    private fun hotspotDetails(r: WifiManager.LocalOnlyHotspotReservation): Map<String, Any?> {
        var ssid: String? = null
        var pass: String? = null
        if (Build.VERSION.SDK_INT >= 30) {
            val c = r.softApConfiguration
            ssid = if (Build.VERSION.SDK_INT >= 33) {
                c.wifiSsid?.toString()
            } else {
                @Suppress("DEPRECATION")
                c.ssid
            }
            pass = c.passphrase
        } else {
            @Suppress("DEPRECATION")
            val c = r.wifiConfiguration
            @Suppress("DEPRECATION")
            ssid = c?.SSID
            @Suppress("DEPRECATION")
            pass = c?.preSharedKey
        }
        return mapOf("ssid" to ssid?.removeSurrounding("\""), "password" to pass?.removeSurrounding("\""))
    }

    private fun stopHotspot() {
        try {
            hotspot?.close()
        } catch (_: Exception) {
        }
        hotspot = null
    }

    // ------------------------------------------- Bonjour (NSD) for iPhones

    private val nsdType = "_isekaidrop._tcp."

    private fun nsdStart(name: String, port: Int, txt: Map<String, String>, advertise: Boolean = true) {
        val nsd = getSystemService(NSD_SERVICE) as NsdManager
        nsdStop()
        val info = NsdServiceInfo().apply {
            serviceName = name.take(60)
            serviceType = nsdType
            setPort(port)
            for ((k, v) in txt) setAttribute(k, v)
        }
        val reg = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(i: NsdServiceInfo) {}
            override fun onRegistrationFailed(i: NsdServiceInfo, e: Int) {}
            override fun onServiceUnregistered(i: NsdServiceInfo) {}
            override fun onUnregistrationFailed(i: NsdServiceInfo, e: Int) {}
        }
        val disc = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String) {}
            override fun onDiscoveryStopped(t: String) {}
            override fun onStartDiscoveryFailed(t: String, e: Int) {}
            override fun onStopDiscoveryFailed(t: String, e: Int) {}
            override fun onServiceLost(i: NsdServiceInfo) {}
            override fun onServiceFound(i: NsdServiceInfo) {
                runOnUiThread {
                    resolveQueue.addLast(i)
                    resolveNext()
                }
            }
        }
        try {
            // Audit #8: "Visible" off stops only advertising; browsing continues.
            if (advertise) {
                nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, reg)
                nsdReg = reg
            }
            nsd.discoverServices(nsdType, NsdManager.PROTOCOL_DNS_SD, disc)
            nsdDisc = disc
        } catch (_: Exception) {
        }
    }

    /** Android resolves one service at a time, so resolves are queued. */
    private fun resolveNext() {
        if (resolving) return
        val next = resolveQueue.removeFirstOrNull() ?: return
        resolving = true
        val nsd = getSystemService(NSD_SERVICE) as NsdManager
        try {
            @Suppress("DEPRECATION")
            nsd.resolveService(next, object : NsdManager.ResolveListener {
                override fun onResolveFailed(i: NsdServiceInfo, e: Int) {
                    runOnUiThread {
                        resolving = false
                        resolveNext()
                    }
                }

                override fun onServiceResolved(i: NsdServiceInfo) {
                    @Suppress("DEPRECATION")
                    val host = i.host
                    val txt = i.attributes.mapValues { (_, v) -> v?.let { String(it, Charsets.UTF_8) } ?: "" }
                    runOnUiThread {
                        resolving = false
                        if (host is Inet4Address) {
                            channel?.invokeMethod("bonjourFound", mapOf(
                                "name" to i.serviceName,
                                "host" to host.hostAddress,
                                "port" to i.port,
                                "txt" to txt,
                            ))
                        }
                        resolveNext()
                    }
                }
            })
        } catch (_: Exception) {
            resolving = false
        }
    }

    private fun nsdStop() {
        val nsd = getSystemService(NSD_SERVICE) as NsdManager
        try { nsdReg?.let { nsd.unregisterService(it) } } catch (_: Exception) {}
        try { nsdDisc?.let { nsd.stopServiceDiscovery(it) } } catch (_: Exception) {}
        nsdReg = null
        nsdDisc = null
    }
}
