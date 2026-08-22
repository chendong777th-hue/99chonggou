package vip.ninechat.pro.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ChatNotificationClickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val payload = AppSystemNotificationPlugin.payloadFromIntent(intent) ?: return
        AppSystemNotificationPlugin.storePendingClick(context.applicationContext, payload)
        AppSystemNotificationPlugin.dispatchClick(context.applicationContext, payload)

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            context.startActivity(launch)
        }
    }
}
