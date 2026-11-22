package com.isujaykumar.isekaidrop

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * C1 (0.11.4): Android 10+ receive without the double copy.
 *
 * Received bytes are written straight into a hidden MediaStore Downloads
 * item (IS_PENDING=1). This runs on the "isekai_drop/media" channel, which
 * has its own serial background task queue, so writes never block the UI
 * thread and happen in order. The item becomes visible (IS_PENDING=0) only
 * after Dart verified the SHA-256; on any failure Dart asks to delete it.
 * Android 9 and older do not use this (no MediaStore.Downloads).
 * Logs and errors never contain file names.
 */
class MediaWriter(private val context: Context) {
    private class Item(val uri: Uri, val pfd: ParcelFileDescriptor) {
        val out = FileOutputStream(pfd.fileDescriptor)
    }

    private val items = ConcurrentHashMap<Int, Item>()
    private val next = AtomicInteger(1)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "available" -> result.success(Build.VERSION.SDK_INT >= 29)
                "mediaCreate" -> result.success(
                    create(call.argument<String>("name")!!, call.argument<String>("sub") ?: ""),
                )
                "mediaOpen" -> result.success(open(Uri.parse(call.argument<String>("id")!!)))
                "mediaWrite" -> {
                    item(call).out.write(call.argument<ByteArray>("b")!!)
                    result.success(null)
                }
                "mediaSize" -> result.success(item(call).out.channel.size())
                "mediaHash" -> result.success(hash(item(call)))
                "mediaPublish" -> result.success(publish(call.argument<Int>("h")!!))
                "mediaClose" -> {
                    items.remove(call.argument<Int>("h"))?.let { closeQuietly(it) }
                    result.success(null)
                }
                "mediaDelete" -> {
                    call.argument<Int>("h")?.let { h -> items.remove(h)?.let { closeQuietly(it) } }
                    val uri = Uri.parse(call.argument<String>("id")!!)
                    items.entries.removeIf { e ->
                        if (e.value.uri == uri) { closeQuietly(e.value); true } else false
                    }
                    context.contentResolver.delete(uri, null, null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Class name only: no file names, no paths.
            result.error("media_failed", e.javaClass.simpleName, null)
        }
    }

    private fun item(call: MethodCall): Item =
        items[call.argument<Int>("h")!!] ?: throw IllegalStateException("closed")

    private fun create(name: String, sub: String): Map<String, Any> {
        if (Build.VERSION.SDK_INT < 29) throw IllegalStateException("old android")
        val rel = Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop" + (if (sub.isEmpty()) "" else "/$sub")
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.RELATIVE_PATH, rel)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("insert failed")
        try {
            val pfd = resolver.openFileDescriptor(uri, "rw")
                ?: throw IllegalStateException("open failed")
            val h = next.getAndIncrement()
            items[h] = Item(uri, pfd)
            return mapOf("h" to h, "id" to uri.toString())
        } catch (e: Exception) {
            try { resolver.delete(uri, null, null) } catch (_: Exception) {}
            throw e
        }
    }

    /** Opens a kept hidden item again; writing continues at its end. */
    private fun open(uri: Uri): Map<String, Any> {
        if (Build.VERSION.SDK_INT < 29) throw IllegalStateException("old android")
        val pfd = context.contentResolver.openFileDescriptor(uri, "rw")
            ?: throw IllegalStateException("open failed")
        val it = Item(uri, pfd)
        val size = it.out.channel.size()
        it.out.channel.position(size)
        val h = next.getAndIncrement()
        items[h] = it
        return mapOf("h" to h, "size" to size)
    }

    /** Native SHA-256 of everything written, read back from byte 0. */
    private fun hash(it: Item): String {
        it.out.flush()
        // Positional reads: the write position is not moved. The stream
        // does not own the descriptor, so it is not closed here.
        val ch = FileInputStream(it.pfd.fileDescriptor).channel
        val md = MessageDigest.getInstance("SHA-256")
        val buf = ByteBuffer.allocate(1 shl 20)
        var pos = 0L
        while (true) {
            buf.clear()
            val n = ch.read(buf, pos)
            if (n <= 0) break
            buf.flip()
            md.update(buf)
            pos += n
        }
        val sb = StringBuilder(64)
        for (b in md.digest()) sb.append(String.format("%02x", b.toInt() and 0xff))
        return sb.toString()
    }

    /** Verified: make the item visible. Returns where it was saved. */
    private fun publish(h: Int): String {
        val it = items.remove(h) ?: throw IllegalStateException("closed")
        try {
            it.out.flush()
            it.pfd.fileDescriptor.sync()
        } finally {
            closeQuietly(it)
        }
        val resolver = context.contentResolver
        val values = ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }
        resolver.update(it.uri, values, null, null)
        var name = ""
        var rel = Environment.DIRECTORY_DOWNLOADS + "/Isekai Drop/"
        resolver.query(
            it.uri,
            arrayOf(MediaStore.Downloads.DISPLAY_NAME, MediaStore.Downloads.RELATIVE_PATH),
            null, null, null,
        )?.use { c ->
            if (c.moveToFirst()) {
                if (!c.isNull(0)) name = c.getString(0)
                if (!c.isNull(1)) rel = c.getString(1)
            }
        }
        // Same form as exportToDownloads: "Downloads/Isekai Drop/<sub/>name".
        val shown = rel.trimEnd('/').replaceFirst(Environment.DIRECTORY_DOWNLOADS, "Downloads")
        return "$shown/$name"
    }

    private fun closeQuietly(it: Item) {
        try { it.pfd.close() } catch (_: Exception) {}
    }
}
