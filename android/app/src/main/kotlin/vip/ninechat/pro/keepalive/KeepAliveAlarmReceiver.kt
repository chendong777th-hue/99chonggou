package vip.ninechat.pro.keepalive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import vip.ninechat.pro.logging.SilentLog as Log

class KeepAliveAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val reason = intent?.getStringExtra(EXTRA_REASON) ?: "alarm"
        Log.d(TAG, "alarm received reason=$reason")
        KeepAliveForegroundService.start(context.applicationContext, "alarm:$reason")
    }

    companion object {
        private const val TAG = "AndroidKeepAlive"
        const val EXTRA_REASON = "reason"
    }
}
