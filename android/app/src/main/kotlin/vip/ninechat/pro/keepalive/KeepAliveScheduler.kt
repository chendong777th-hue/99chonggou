package vip.ninechat.pro.keepalive

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

object KeepAliveScheduler {
    private const val TAG = "AndroidKeepAlive"
    private const val REQUEST_CODE = 0x9902
    private const val PREFS = "keep_alive_scheduler"
    private const val KEY_LAST_SCHEDULE_AT = "last_schedule_at"
    private const val DEBOUNCE_MS = 5000L

    fun scheduleRestart(context: Context, delayMs: Long, reason: String) {
        val appContext = context.applicationContext
        val now = System.currentTimeMillis()
        val prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastAt = prefs.getLong(KEY_LAST_SCHEDULE_AT, 0L)
        if (now - lastAt < DEBOUNCE_MS) {
            Log.d(TAG, "skip schedule debounce reason=$reason")
            return
        }
        prefs.edit().putLong(KEY_LAST_SCHEDULE_AT, now).apply()

        val alarmManager =
            appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(appContext, KeepAliveAlarmReceiver::class.java).apply {
            putExtra(KeepAliveAlarmReceiver.EXTRA_REASON, reason)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getBroadcast(
            appContext,
            REQUEST_CODE,
            intent,
            flags,
        )
        val triggerAt = SystemClock.elapsedRealtime() + delayMs.coerceAtLeast(1000L)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
            Log.d(TAG, "scheduleRestart reason=$reason delayMs=$delayMs")
        } catch (e: SecurityException) {
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAt,
                pendingIntent,
            )
            Log.w(TAG, "scheduleRestart fallback reason=$reason error=$e")
        }
    }
}
