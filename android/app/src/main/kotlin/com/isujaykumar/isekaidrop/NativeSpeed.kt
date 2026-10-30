package com.isujaykumar.isekaidrop

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.ServerSocketChannel
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * 0.10.2 Speed test: a plain Java NIO TCP probe (no Dart, no encryption),
 * so a slow result can be split into "the radio/network" and "the app".
 * Only zeros travel. The receiving port accepts a fixed number of
 * connections that each start with a one-time token, and closes after the
 * test (or after 20 s without connections). Nothing is written to disk.
 */
class NativeSpeed {
    private val main = Handler(Looper.getMainLooper())

    private class Sink(val server: ServerSocketChannel, val streams: Int, val token: ByteArray) {
        val bytes = AtomicLong(0)
        val firstNs = AtomicLong(0)
        @Volatile var lastNs = 0L
        val chans = CopyOnWriteArrayList<SocketChannel>()
        val accepted = AtomicInteger(0)
        val finished = AtomicInteger(0)
        @Volatile var closed = false
        var rcvBuf = 0
    }

    private val sinks = ConcurrentHashMap<Int, Sink>()
    private val nextId = AtomicInteger(1)

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "nativeSinkStart" -> sinkStart(
                (call.argument<Number>("streams") ?: 1).toInt().coerceIn(1, 8),
                call.argument<String>("token") ?: "",
                result,
            )
            "nativeSinkEnd" -> sinkEnd(
                (call.argument<Number>("id") ?: 0).toInt(),
                (call.argument<Number>("expect") ?: 0).toLong(),
                (call.argument<Number>("waitMs") ?: 15000).toLong(),
                result,
            )
            "nativeSend" -> send(
                call.argument<String>("host") ?: "",
                (call.argument<Number>("port") ?: 0).toInt(),
                call.argument<String>("token") ?: "",
                (call.argument<Number>("streams") ?: 1).toInt().coerceIn(1, 8),
                (call.argument<Number>("bytes") ?: 0).toLong(),
                (call.argument<Number>("limitMs") ?: 15000).toLong(),
                result,
            )
            else -> return false
        }
        return true
    }

    private fun reply(r: MethodChannel.Result, v: Any?) = main.post { r.success(v) }
    private fun fail(r: MethodChannel.Result, code: String) = main.post { r.error(code, code, null) }

    private fun readFully(ch: SocketChannel, n: Int): ByteArray? {
        val b = ByteBuffer.allocate(n)
        while (b.hasRemaining()) if (ch.read(b) < 0) return null
        return b.array()
    }

    private fun sinkStart(streams: Int, token: String, result: MethodChannel.Result) {
        if (token.length < 16) { fail(result, "bad_token"); return }
        val ss: ServerSocketChannel
        try {
            ss = ServerSocketChannel.open()
            ss.socket().receiveBufferSize = 4 * 1024 * 1024
            ss.bind(InetSocketAddress(0), streams)
        } catch (e: Exception) {
            fail(result, "bind_failed"); return
        }
        val id = nextId.getAndIncrement()
        val s = Sink(ss, streams, token.toByteArray(Charsets.UTF_8))
        try { s.rcvBuf = ss.socket().receiveBufferSize } catch (_: Exception) {}
        sinks[id] = s
        // Nobody came within 20 s: give the port back.
        main.postDelayed({ if (s.accepted.get() < s.streams) close(id) }, 20000)
        Thread({
            try {
                while (!s.closed && s.accepted.get() < s.streams) {
                    val c = ss.accept() ?: break
                    Thread({ serve(s, c) }, "isekai-speed-rx").start()
                }
            } catch (_: Exception) {
            } finally {
                try { ss.close() } catch (_: Exception) {}
            }
        }, "isekai-speed-accept").start()
        reply(result, mapOf("id" to id, "port" to ss.socket().localPort))
    }

    private fun serve(s: Sink, c: SocketChannel) {
        var counted = false
        try {
            val need = s.token.size + if (s.streams > 1) 1 else 0
            val got = readFully(c, need)
            if (got == null || !got.copyOfRange(0, s.token.size).contentEquals(s.token)) { c.close(); return }
            if (s.accepted.incrementAndGet() > s.streams) { c.close(); return }
            counted = true
            s.chans.add(c)
            val buf = ByteBuffer.allocateDirect(1024 * 1024)
            while (!s.closed) {
                val n = c.read(buf)
                if (n < 0) break
                if (n > 0) {
                    val now = System.nanoTime()
                    s.firstNs.compareAndSet(0, now)
                    s.bytes.addAndGet(n.toLong())
                    s.lastNs = now
                }
                buf.clear()
            }
        } catch (_: Exception) {
        } finally {
            if (counted) s.finished.incrementAndGet()
            try { c.close() } catch (_: Exception) {}
        }
    }

    private fun close(id: Int) {
        val s = sinks.remove(id) ?: return
        s.closed = true
        try { s.server.close() } catch (_: Exception) {}
        for (c in s.chans) try { c.close() } catch (_: Exception) {}
    }

    private fun sinkEnd(id: Int, expect: Long, waitMs: Long, result: MethodChannel.Result) {
        val s = sinks[id] ?: run { fail(result, "no_sink"); return }
        Thread({
            val until = System.currentTimeMillis() + waitMs.coerceIn(0, 60000)
            while (System.currentTimeMillis() < until) {
                if (s.bytes.get() >= expect && expect > 0) break
                if (s.accepted.get() > 0 && s.finished.get() >= s.accepted.get()) break
                Thread.sleep(20)
            }
            val first = s.firstNs.get()
            val micros = if (first > 0) (s.lastNs - first) / 1000 else 0
            val out = mapOf(
                "bytes" to s.bytes.get(),
                "micros" to micros,
                "streams" to s.accepted.get().coerceAtMost(s.streams),
                "rcvBuf" to s.rcvBuf,
            )
            close(id)
            reply(result, out)
        }, "isekai-speed-end").start()
    }

    private fun send(host: String, port: Int, token: String, streams: Int, bytes: Long, limitMs: Long,
                     result: MethodChannel.Result) {
        Thread({
            val chans = mutableListOf<SocketChannel>()
            try {
                val tok = token.toByteArray(Charsets.UTF_8)
                for (i in 0 until streams) {
                    val c = SocketChannel.open()
                    chans.add(c)
                    c.socket().sendBufferSize = 4 * 1024 * 1024
                    c.socket().tcpNoDelay = false
                    c.socket().connect(InetSocketAddress(host, port), 5000)
                    val head = ByteBuffer.wrap(if (streams > 1) tok + byteArrayOf(i.toByte()) else tok)
                    while (head.hasRemaining()) c.write(head)
                }
            } catch (e: Exception) {
                for (c in chans) try { c.close() } catch (_: Exception) {}
                fail(result, "connect_failed")
                return@Thread
            }
            val sndBuf = try { chans[0].socket().sendBufferSize } catch (_: Exception) { 0 }
            val sent = AtomicLong(0)
            val claimed = AtomicLong(0)
            val start = System.nanoTime()
            val deadline = start + limitMs * 1_000_000
            val workers = chans.map { c ->
                Thread({
                    val buf = ByteBuffer.allocateDirect(1024 * 1024)
                    try {
                        while (System.nanoTime() < deadline) {
                            val k = minOf(buf.capacity().toLong(), bytes - claimed.get())
                            if (k <= 0) break
                            if (claimed.addAndGet(k) > bytes) { claimed.addAndGet(-k); continue }
                            buf.clear(); buf.limit(k.toInt())
                            while (buf.hasRemaining()) c.write(buf)
                            sent.addAndGet(k)
                        }
                        c.socket().shutdownOutput()
                    } catch (_: Exception) {
                    }
                }, "isekai-speed-tx").apply { start() }
            }
            for (w in workers) w.join()
            val micros = (System.nanoTime() - start) / 1000
            for (c in chans) try { c.close() } catch (_: Exception) {}
            reply(result, mapOf("bytes" to sent.get(), "micros" to micros, "sndBuf" to sndBuf))
        }, "isekai-speed-send").start()
    }

    fun dispose() {
        for (id in sinks.keys.toList()) close(id)
    }
}
