package vip.ninechat.pro.keepalive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class KeepAliveRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "boot/package event action=$action")
        KeepAliveForegroundService.start(context.applicationContext, "boot")
    }

    companion object {
        private const val TAG = "AndroidKeepAlive"
    }
}
