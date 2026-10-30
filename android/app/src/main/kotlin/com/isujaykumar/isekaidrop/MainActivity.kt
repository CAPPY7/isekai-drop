package com.isujaykumar.isekaidrop

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import java.net.Inet4Address
import android.net.wifi.WifiInfo
import android.provider.DocumentsContract
import android.view.WindowManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
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
 *  - keeping the screen on while a transfer runs.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "isekai_drop/android"
    private val pickRequest = 4711
    private val folderRequest = 4712
    private var pendingFolder: MethodChannel.Result? = null

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
    private var channel: MethodChannel? = null
    private var nsdReg: NsdManager.RegistrationListener? = null
    private var nsdDisc: NsdManager.DiscoveryListener? = null
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false
    private var pendingPick: MethodChannel.Result? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val io = Executors.newSingleThreadExecutor()
    // 0.9.2: open files being sent. Each keeps a SHA-256 of everything read
    // so far (MessageDigest is hardware-accelerated on ARMv8; the Dart
    // SHA-256 is pure Dart and much slower).
    private class Reader(val ins: java.io.InputStream) {
        val digest: java.security.MessageDigest = java.security.MessageDigest.getInstance("SHA-256")
        var bytes = 0L
    }
    private val readers = java.util.concurrent.ConcurrentHashMap<Int, Reader>()
    private val nextReader = java.util.concurrent.atomic.AtomicInteger(1)
    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    // 0.10.2: why the Wi-Fi/CPU locks are held ("job", "speed").
    private val awakeReasons = mutableSetOf<String>()
    private val nativeSpeed = NativeSpeed()
    // 0.10.0 Fast direct (see DirectLinks.kt).
    private var direct: DirectLinks? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 0.9.2 speed: file reading and hashing run on background task
        // queues (not the Android UI thread), with their own channels.
        // Before, every 512 KiB chunk hopped through the UI thread.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger, "isekai_drop/android_read",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result -> onReadCall(call, result) }
        MethodChannel(
            messenger, "isekai_drop/android_hash",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method == "hashFile") hashFile(call.argument<String>("path")!!, result)
            else result.notImplemented()
        }
        val directChannel = MethodChannel(messenger, "isekai_drop/direct")
        val dl = DirectLinks(this, directChannel) {
            boundTo = null
            evaluateBinding()
        }
        direct = dl
        directChannel.setMethodCallHandler { call, result -> dl.handle(call, result) }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFiles" -> pickFiles(result)
                    // 0.9.1: picked files are read through a Java stream
                    // (ContentResolver). Re-opening "/proc/self/fd/N" from
                    // Dart fails on Android 11+ scoped storage (EACCES),
                    // which made every send fail at 0%.
                    // (0.9.2: openRead/readChunk/closeRead moved to the
                    // "isekai_drop/android_read" background channel.)
                    "ensureLegacyStorage" -> ensureLegacyStorage(result)
                    // Audit #15: partial files live here (not cache: the
                    // system may clear it; not backed up to the cloud).
                    "noBackupDir" -> result.success(noBackupFilesDir.absolutePath)
                    // Audit #16: free bytes before accepting a transfer.
                    "freeSpace" -> result.success(
                        try { android.os.StatFs(call.argument<String>("path")!!).availableBytes } catch (e: Exception) { null }
                    )
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
                    // 0.10.1 Speed test: write zeros into Downloads, then delete.
                    "speedWriteDownloads" -> speedWriteDownloads(
                        (call.argument<Number>("bytes") ?: 0).toLong(),
                        (call.argument<Number>("limitMs") ?: 15000).toLong(),
                        result,
                    )
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") == true
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        setAwake("job", on)
                        result.success(null)
                    }
                    // 0.10.2: Wi-Fi lock + CPU wake lock without the screen
                    // flag (Speed test on both devices). Returns what is held.
                    "transferAwake" -> result.success(
                        setAwake(call.argument<String>("reason") ?: "speed", call.argument<Boolean>("on") == true)
                    )
                    "nativeSinkStart", "nativeSinkEnd", "nativeSend" -> nativeSpeed.handle(call, result)
                    "localNets" -> {
                        try {
                            result.success(localNetsInfo())
                        } catch (e: Exception) {
                            result.success(null)
                        }
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
                            // Same moment: make sure traffic to a Wi-Fi
                            // without internet stays on Wi-Fi (Phase 7d).
                            watchWifiForBinding()
                            result.success(true)
                        } catch (e: Exception) {
                            watchWifiForBinding()
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------- Wi-Fi without internet (Phase 7d)
    //
    // When the joined Wi-Fi (e.g. another phone's app hotspot, or a router
    // without internet) has no internet, Android keeps mobile data as the
    // default network. Then our connections and discovery packets can leave
    // over mobile data and never reach the other device. Fix: bind this app's
    // process to that Wi-Fi while it is the only Wi-Fi and the default network
    // is not Wi-Fi; undo it as soon as that is no longer true.

    private var wifiCallback: ConnectivityManager.NetworkCallback? = null
    private val wifiNets = mutableSetOf<Network>()
    @Volatile private var boundTo: Network? = null
    @Volatile private var bindingNote: String? = null

    private fun watchWifiForBinding() {
        if (wifiCallback != null) return
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(n: Network) {
                synchronized(wifiNets) { wifiNets.add(n) }
                evaluateBinding()
            }
            override fun onCapabilitiesChanged(n: Network, c: NetworkCapabilities) {
                evaluateBinding()
            }
            override fun onLost(n: Network) {
                synchronized(wifiNets) { wifiNets.remove(n) }
                evaluateBinding()
            }
        }
        try {
            val req = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            cm.registerNetworkCallback(req, cb)
            wifiCallback = cb
        } catch (_: Exception) {
            bindingNote = "could not watch Wi-Fi"
        }
    }

    private fun evaluateBinding() {
        // A Fast direct join owns the binding while it lasts.
        if (direct?.ownsBinding == true) {
            bindingNote = "Fast direct link in use"
            return
        }
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        try {
            val wifis = synchronized(wifiNets) { wifiNets.toList() }
            val active = cm.activeNetwork
            val activeIsWifi = active != null &&
                cm.getNetworkCapabilities(active)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            val target = if (!activeIsWifi && wifis.size == 1) wifis[0] else null
            if (target != boundTo) {
                cm.bindProcessToNetwork(target)
                boundTo = target
            }
            bindingNote = when {
                target != null -> "Wi-Fi has no internet: this app is kept on Wi-Fi"
                activeIsWifi -> "Wi-Fi is the default network"
                wifis.size > 1 -> "several Wi-Fi networks: not binding"
                else -> null
            }
        } catch (_: Exception) {
            bindingNote = "binding to Wi-Fi failed"
        }
    }

    /** This device's IPv4 addresses with prefix and Wi-Fi flag, for
     *  discovery (subnet broadcast) and the QR code. Own addresses only.
     *  (Not "networkInfo": that name is the Diagnostics link-speed call.) */
    private fun localNetsInfo(): Map<String, Any?> {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val wifiIfaces = mutableSetOf<String>()
        try {
            @Suppress("DEPRECATION")
            for (n in cm.allNetworks) {
                val caps = cm.getNetworkCapabilities(n) ?: continue
                if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) continue
                cm.getLinkProperties(n)?.interfaceName?.let { wifiIfaces.add(it) }
            }
        } catch (_: Exception) {
        }
        val list = mutableListOf<Map<String, Any?>>()
        try {
            for (ni in java.net.NetworkInterface.getNetworkInterfaces()?.toList() ?: emptyList()) {
                if (!ni.isUp || ni.isLoopback) continue
                for (ia in ni.interfaceAddresses) {
                    val a = ia.address as? Inet4Address ?: continue
                    list.add(mapOf(
                        "name" to ni.name,
                        "ip" to a.hostAddress,
                        "prefix" to ia.networkPrefixLength.toInt(),
                        "wifi" to (ni.name in wifiIfaces),
                    ))
                }
            }
        } catch (_: Exception) {
        }
        return mapOf("nets" to list, "binding" to bindingNote)
    }

    override fun onDestroy() {
        try {
            direct?.dispose()
        } catch (_: Exception) {
        }
        direct = null
        nativeSpeed.dispose()
        synchronized(awakeReasons) { awakeReasons.clear() }
        setWifiLock(false)
        setWakeLock(false)
        try {
            multicastLock?.release()
        } catch (_: Exception) {
        }
        try {
            wifiCallback?.let {
                (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it)
            }
            if (boundTo != null) {
                (getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager).bindProcessToNetwork(null)
            }
        } catch (_: Exception) {
        }
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

    private fun onReadCall(call: MethodCall, result: MethodChannel.Result) {
        // Runs on a background task queue: blocking reads are fine here.
        when (call.method) {
            "openRead" -> openRead(call.argument<String>("uri")!!, result)
            "readChunk" -> readChunk(call.argument<Int>("id")!!, call.argument<Int>("max")!!, result)
            // SHA-256 (hex) and byte count of everything read so far.
            "readDigest" -> {
                val r = readers[call.argument<Int>("id")!!]
                if (r == null) result.error("closed", "Reader closed", null)
                else result.success(mapOf("sha256" to hex(r.digest.digest()), "bytes" to r.bytes))
            }
            "closeRead" -> {
                try {
                    readers.remove(call.argument<Int>("id")!!)?.ins?.close()
                } catch (_: Exception) {
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hex(b: ByteArray): String {
        val sb = StringBuilder(b.size * 2)
        for (x in b) sb.append(String.format("%02x", x.toInt() and 0xff))
        return sb.toString()
    }

    private fun openRead(uri: String, result: MethodChannel.Result) {
        try {
            val ins = contentResolver.openInputStream(Uri.parse(uri))
                ?: throw java.io.IOException("no stream")
            val id = nextReader.getAndIncrement()
            readers[id] = Reader(ins)
            result.success(id)
        } catch (e: SecurityException) {
            result.error("no_permission", "No permission to read the file", null)
        } catch (e: java.io.FileNotFoundException) {
            result.error("not_found", "File not found", null)
        } catch (e: Exception) {
            result.error("open_failed", e.javaClass.simpleName, null)
        }
    }

    /** Reads up to [max] bytes (fewer only at the end). Empty = end of file. */
    private fun readChunk(id: Int, max: Int, result: MethodChannel.Result) {
        val r = readers[id]
        if (r == null) {
            result.error("closed", "Reader closed", null)
            return
        }
        try {
            val buf = ByteArray(max.coerceIn(4096, 8 * 1024 * 1024))
            var n = 0
            while (n < buf.size) {
                val got = r.ins.read(buf, n, buf.size - n)
                if (got < 0) break
                n += got
            }
            r.digest.update(buf, 0, n)
            r.bytes += n
            result.success(if (n == buf.size) buf else buf.copyOf(n))
        } catch (e: Exception) {
            result.error("read_failed", e.javaClass.simpleName, null)
        }
    }

    /** 0.9.2: SHA-256 (hex) of a received temp file, natively. */
    private fun hashFile(path: String, result: MethodChannel.Result) {
        try {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            val buf = ByteArray(1 shl 20)
            FileInputStream(File(path)).use { ins ->
                while (true) {
                    val n = ins.read(buf)
                    if (n < 0) break
                    md.update(buf, 0, n)
                }
            }
            result.success(hex(md.digest()))
        } catch (e: Exception) {
            result.error("hash_failed", e.javaClass.simpleName, null)
        }
    }

    /**
     * 0.10.2: keep Wi-Fi out of power save and the CPU awake while a
     * transfer or Speed test runs. Below Android 14: WIFI_MODE_FULL_HIGH_PERF.
     * Android 14+: HIGH_PERF no longer exists (the system turns it into
     * LOW_LATENCY anyway), so LOW_LATENCY is asked for directly; Android
     * applies it only while the app is in front with the screen on, and only
     * to the router connection. (0.9.2 took no lock at all on Android 14+.)
     */
    private fun setAwake(reason: String, on: Boolean): String {
        val any = synchronized(awakeReasons) {
            if (on) awakeReasons.add(reason) else awakeReasons.remove(reason)
            awakeReasons.isNotEmpty()
        }
        setWifiLock(any)
        setWakeLock(any)
        return awakeNote()
    }

    private fun awakeNote(): String {
        val w = wifiLock?.isHeld == true
        val mode = if (Build.VERSION.SDK_INT >= 34) "low-latency" else "high-perf"
        return listOf(
            if (w) "Wi-Fi lock $mode" else "no Wi-Fi lock",
            if (wakeLock?.isHeld == true) "CPU wake lock" else "no wake lock",
        ).joinToString(", ")
    }

    @Suppress("DEPRECATION")
    private fun setWifiLock(on: Boolean) {
        try {
            if (on) {
                if (wifiLock?.isHeld == true) return
                val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                val mode = if (Build.VERSION.SDK_INT >= 34) WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                    else WifiManager.WIFI_MODE_FULL_HIGH_PERF
                wifiLock = wifi.createWifiLock(mode, "isekai-drop-transfer").apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } else {
                wifiLock?.let { if (it.isHeld) it.release() }
                wifiLock = null
            }
        } catch (_: Exception) {
        }
    }

    private fun setWakeLock(on: Boolean) {
        try {
            if (on) {
                if (wakeLock?.isHeld == true) return
                val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                wakeLock = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "isekaidrop:transfer").apply {
                    setReferenceCounted(false)
                    // Safety net: never held longer than 2 hours at a time.
                    acquire(2 * 60 * 60 * 1000L)
                }
            } else {
                wakeLock?.let { if (it.isHeld) it.release() }
                wakeLock = null
            }
        } catch (_: Exception) {
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

    /** 0.10.1 Speed test: how fast a file can be written where received files
     *  are saved (MediaStore Downloads), with the same 1 MiB pieces the save
     *  copy uses. Writes zeros only and deletes the test file at once. */
    private fun speedWriteDownloads(bytes: Long, limitMs: Long, result: MethodChannel.Result) {
        io.execute {
            var uri: android.net.Uri? = null
            var legacy: File? = null
            try {
                val buf = ByteArray(1 shl 20)
                val out: java.io.OutputStream
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, "isekai-speed-test.tmp")
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop")
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("insert failed")
                    out = contentResolver.openOutputStream(uri)!!
                } else {
                    val f = File(legacyBase(), ".isekai-speed-test.tmp")
                    f.parentFile?.mkdirs()
                    legacy = f
                    out = f.outputStream()
                }
                val t0 = System.nanoTime()
                val deadline = t0 + limitMs * 1_000_000L
                var n = 0L
                out.use {
                    while (n < bytes && System.nanoTime() < deadline) {
                        val k = minOf(buf.size.toLong(), bytes - n).toInt()
                        it.write(buf, 0, k)
                        n += k
                    }
                    it.flush()
                }
                val micros = (System.nanoTime() - t0) / 1000
                runOnUiThread { result.success(mapOf("bytes" to n, "micros" to micros)) }
            } catch (e: Exception) {
                runOnUiThread { result.error("speed_write_failed", e.javaClass.simpleName, null) }
            } finally {
                try { uri?.let { contentResolver.delete(it, null, null) } } catch (_: Exception) {}
                try { legacy?.delete() } catch (_: Exception) {}
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
        val out = mutableMapOf<String, Any?>("transport" to "none", "hotspotByApp" to false)
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
                // 0.10.1: send/receive link speeds (Android 10+).
                if (Build.VERSION.SDK_INT >= 29) {
                    if (info.txLinkSpeedMbps > 0) out["txMbps"] = info.txLinkSpeedMbps
                    if (info.rxLinkSpeedMbps > 0) out["rxMbps"] = info.rxLinkSpeedMbps
                }
            }
        } catch (_: Exception) {
        }
        return out
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == DirectLinks.PERMISSION_REQUEST) {
            direct?.onPermissionResult()
            return
        }
        if (requestCode == legacyRequest) {
            val r = pendingLegacy ?: return
            pendingLegacy = null
            r.success(legacyGranted())
        }
    }

    // ------------------------------------------- Bonjour (NSD) for iPhones

    private val nsdType = "_isekaidrop._tcp."

    /** Tells Dart what NSD did (for Diagnostics). [code] is the NsdManager
     *  error code, or 0. Never includes names or addresses. */
    private fun nsdEvent(what: String, code: Int = 0) {
        runOnUiThread {
            try {
                channel?.invokeMethod("bonjourEvent", mapOf("what" to what, "code" to code))
            } catch (_: Exception) {
            }
        }
    }

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
            override fun onServiceRegistered(i: NsdServiceInfo) { nsdEvent("registered") }
            override fun onRegistrationFailed(i: NsdServiceInfo, e: Int) { nsdEvent("register_failed", e) }
            override fun onServiceUnregistered(i: NsdServiceInfo) {}
            override fun onUnregistrationFailed(i: NsdServiceInfo, e: Int) {}
        }
        val disc = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String) { nsdEvent("discovery_started") }
            override fun onDiscoveryStopped(t: String) {}
            override fun onStartDiscoveryFailed(t: String, e: Int) { nsdEvent("discovery_failed", e) }
            override fun onStopDiscoveryFailed(t: String, e: Int) {}
            override fun onServiceLost(i: NsdServiceInfo) {}
            override fun onServiceFound(i: NsdServiceInfo) {
                nsdEvent("found")
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
            nsdEvent("start_exception")
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
                    nsdEvent("resolve_failed", e)
                    runOnUiThread {
                        resolving = false
                        resolveNext()
                    }
                }

                override fun onServiceResolved(i: NsdServiceInfo) {
                    @Suppress("DEPRECATION")
                    val host = i.host
                    val txt = i.attributes.mapValues { (_, v) -> v?.let { String(it, Charsets.UTF_8) } ?: "" }
                    nsdEvent(if (host is Inet4Address) "resolved" else "resolved_not_ipv4")
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
            nsdEvent("resolve_exception")
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
