package vip.ninechat.pro.keepalive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import vip.ninechat.pro.MainActivity
import vip.ninechat.pro.R

class KeepAliveForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        createChannel()
        Log.d(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == stopAction()) {
            Log.d(TAG, "stop requested")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            running = false
            stopSelf()
            return START_NOT_STICKY
        }

        val reason = intent?.getStringExtra(EXTRA_REASON) ?: "unknown"
        startForeground(NOTIFICATION_ID, buildNotification())
        running = true
        Log.d(
            TAG,
            "start reason=$reason action=${startAction()}",
        )
        KeepAliveWatchdogWorker.schedule(applicationContext)
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "onTaskRemoved schedule restart")
        KeepAliveScheduler.scheduleRestart(applicationContext, 3000L, "task_removed")
    }

    override fun onDestroy() {
        running = false
        Log.d(TAG, "onDestroy schedule restart")
        KeepAliveScheduler.scheduleRestart(applicationContext, 5000L, "destroy")
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.keep_alive_notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.keep_alive_notification_channel_desc)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.keep_alive_notification_title))
            .setContentText(getString(R.string.keep_alive_notification_text))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        private const val TAG = "AndroidKeepAlive"
        const val NOTIFICATION_ID = 0x9901
        const val CHANNEL_ID = "keep_alive_channel"
        const val EXTRA_REASON = "reason"
        private const val ACTION_START_SUFFIX = ".action.KEEP_ALIVE_START"
        private const val ACTION_STOP_SUFFIX = ".action.KEEP_ALIVE_STOP"

        @Volatile
        private var running = false

        fun start(context: Context, reason: String) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, KeepAliveForegroundService::class.java).apply {
                action = appContext.packageName + ACTION_START_SUFFIX
                putExtra(EXTRA_REASON, reason)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        }

        fun stop(context: Context, reason: String) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, KeepAliveForegroundService::class.java).apply {
                action = appContext.packageName + ACTION_STOP_SUFFIX
                putExtra(EXTRA_REASON, reason)
            }
            appContext.startService(intent)
        }

        fun isRunning(context: Context): Boolean {
            if (running) {
                return true
            }
            val manager =
                context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            @Suppress("DEPRECATION")
            for (service in manager.getRunningServices(Int.MAX_VALUE)) {
                if (KeepAliveForegroundService::class.java.name == service.service.className) {
                    return true
                }
            }
            return false
        }
    }

    private fun startAction(): String = packageName + ACTION_START_SUFFIX

    private fun stopAction(): String = packageName + ACTION_STOP_SUFFIX
}
