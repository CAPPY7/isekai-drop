package com.isujaykumar.isekaidrop

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * D2 (0.12.0): foreground service (type dataSync) while a transfer runs or
 * a request waits for an answer, so Android does not stop the app when you
 * switch to another one. The Dart side (lib/engine/transfer_service.dart)
 * starts, updates and stops it. The notification shows counts and measured
 * bytes only - never file names or device names (lock screen). It does not
 * take any wake lock or Wi-Fi lock: those stay in MainActivity.setAwake.
 */
class TransferService : Service() {
    companion object {
        const val ACTION_CANCEL = "com.isujaykumar.isekaidrop.CANCEL_TRANSFERS"
        private const val CH_PROGRESS = "transfers"
        private const val CH_REQUESTS = "requests"
        private const val ID_PROGRESS = 4801
        private const val ID_REQUEST = 4802

        /** Set by MainActivity: "Cancel" in the notification. */
        var onCancel: (() -> Unit)? = null
        private var instance: TransferService? = null
        private var last: Map<String, Int> = emptyMap()

        private fun channels(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CH_PROGRESS, "Transfers", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Progress of a running transfer"
                },
            )
            nm.createNotificationChannel(
                NotificationChannel(CH_REQUESTS, "Incoming requests", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "A device wants to send you files or pair"
                },
            )
        }

        private fun openApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        private fun mb(b: Int): String = "%.1f MB".format(b / 1_000_000.0)

        fun progressNotification(ctx: Context, s: Map<String, Int>): Notification {
            channels(ctx)
            val sending = s["sending"] ?: 0
            val receiving = s["receiving"] ?: 0
            val done = s["done"] ?: 0
            val total = s["total"] ?: 0
            val title = when {
                sending > 0 && receiving > 0 -> "Sending and receiving files"
                sending > 0 -> "Sending files"
                receiving > 0 -> "Receiving files"
                else -> "Waiting for your answer"
            }
            val cancel = PendingIntent.getService(
                ctx, 1,
                Intent(ctx, TransferService::class.java).setAction(ACTION_CANCEL),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val b = NotificationCompat.Builder(ctx, CH_PROGRESS)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setContentIntent(openApp(ctx))
            if (sending + receiving > 0) {
                b.setContentText(if (total > 0) "${mb(done)} of ${mb(total)}" else "")
                // Bytes moved so far, scaled to 0..1000 (measured, not guessed).
                val pct = if (total > 0) (done.toLong() * 1000 / total).toInt() else 0
                b.setProgress(1000, pct.coerceIn(0, 1000), total <= 0)
                b.addAction(0, "Cancel", cancel)
            }
            return b.build()
        }

        /** Starts or updates. False when Android did not allow the start
         *  (e.g. Android 12+ while the app is in the background). */
        fun update(ctx: Context, s: Map<String, Int>, appVisible: Boolean): Boolean {
            last = s
            requestNotice(ctx, (s["requests"] ?: 0) > 0 && !appVisible)
            val running = instance
            if (running != null) {
                running.show()
                return true
            }
            return try {
                androidx.core.content.ContextCompat.startForegroundService(
                    ctx, Intent(ctx, TransferService::class.java),
                )
                true
            } catch (e: Exception) {
                false
            }
        }

        fun stop(ctx: Context) {
            last = emptyMap()
            requestNotice(ctx, false)
            ctx.stopService(Intent(ctx, TransferService::class.java))
        }

        /** "Incoming request" notice; tapping it opens the app, where the
         *  Accept question is waiting. No names in it. */
        fun requestNotice(ctx: Context, show: Boolean) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!show) {
                nm.cancel(ID_REQUEST)
                return
            }
            channels(ctx)
            try {
                nm.notify(
                    ID_REQUEST,
                    NotificationCompat.Builder(ctx, CH_REQUESTS)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle("A device wants to send you something")
                        .setContentText("Tap to answer")
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                        .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                        .setAutoCancel(true)
                        .setContentIntent(openApp(ctx))
                        .build(),
                )
            } catch (_: SecurityException) {
                // Notifications not allowed: the question waits in the app.
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            onCancel?.invoke()
            return START_NOT_STICKY
        }
        instance = this
        show()
        // Not restarted by Android: a transfer cannot continue without the app.
        return START_NOT_STICKY
    }

    fun show() {
        val n = progressNotification(this, last)
        try {
            ServiceCompat.startForeground(
                this, ID_PROGRESS, n,
                if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0,
            )
        } catch (e: Exception) {
            // Android refused (e.g. started from the background on 12+):
            // no service; the transfer still runs while the app is open.
            instance = null
            stopSelf()
        }
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15+: dataSync time limit reached. Stop cleanly.
        stopSelf()
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
