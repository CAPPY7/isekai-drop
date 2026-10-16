package com.isujaykumar.isekaidrop

import android.app.Activity
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
 *  - a Wi-Fi multicast lock so device discovery packets are received.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "isekai_drop/android"
    private val pickRequest = 4711
    private var pendingPick: MethodChannel.Result? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
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
                    "exportToDownloads" -> exportToDownloads(
                        call.argument<String>("path")!!,
                        call.argument<String>("name")!!,
                        result,
                    )
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

    private fun exportToDownloads(path: String, name: String, result: MethodChannel.Result) {
        io.execute {
            val src = File(path)
            try {
                val where: String
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, name)
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop")
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
                    where = "Downloads/Isekai Drop/$name"
                } else {
                    val dir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "Isekai Drop")
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
}
