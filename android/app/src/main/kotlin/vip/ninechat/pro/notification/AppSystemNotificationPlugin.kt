package vip.ninechat.pro.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import vip.ninechat.pro.R
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AppSystemNotificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app_system_notification")
        channel.setMethodCallHandler(this)
        activeChannel = channel
        ensureNotificationChannel()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (activeChannel == channel) {
            activeChannel = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showChatNotification" -> {
                val title = call.argument<String>("title").orEmpty()
                val body = call.argument<String>("body").orEmpty()
                val conversationID = call.argument<String>("conversationID").orEmpty()
                val ext = call.argument<String>("ext").orEmpty()
                val avatarUrl = call.argument<String>("avatarUrl")
                val notificationId = call.argument<Int>("notificationId")
                val msgKey = call.argument<String>("msgKey")
                val threadId = call.argument<String>("threadId")
                result.success(
                    showChatNotification(
                        title,
                        body,
                        conversationID,
                        ext,
                        avatarUrl,
                        notificationId,
                        msgKey,
                        threadId,
                    ),
                )
            }

            "consumeNotificationClick" -> {
                result.success(readPendingClick(clear = true))
            }

            "cancelAll" -> {
                NotificationManagerCompat.from(appContext).cancelAll()
                result.success(true)
            }

            "cancelNotification" -> {
                val notificationId = call.argument<Int>("notificationId") ?: 0
                NotificationManagerCompat.from(appContext).cancel(notificationId)
                result.success(true)
            }

            "cancelNotificationByMsgKey" -> {
                val msgKey = call.argument<String>("msgKey")?.trim().orEmpty()
                result.success(cancelNotificationByMsgKey(msgKey))
            }

            "clearImChatNotifications" -> {
                val threadId = call.argument<String>("threadId")?.trim().orEmpty()
                result.success(clearImChatNotifications(threadId))
            }

            else -> result.notImplemented()
        }
    }

    private fun clearImChatNotifications(threadId: String): Int {
        val compat = NotificationManagerCompat.from(appContext)
        var cleared = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val manager = appContext.getSystemService(NotificationManager::class.java)
            for (status in manager.activeNotifications) {
                val notification = status.notification ?: continue
                if (!isImChatNotification(notification, threadId)) {
                    continue
                }
                compat.cancel(status.id)
                cleared += 1
            }
        }
        return cleared
    }

    private fun cancelNotificationByMsgKey(msgKey: String): Int {
        if (msgKey.isEmpty()) {
            return 0
        }
        val compat = NotificationManagerCompat.from(appContext)
        var cleared = 0
        val hashId = msgKey.hashCode() and 0x7fffffff
        compat.cancel(hashId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val manager = appContext.getSystemService(NotificationManager::class.java)
            for (status in manager.activeNotifications) {
                val notification = status.notification ?: continue
                val extras = notification.extras ?: continue
                if (!matchesMsgKey(extras, msgKey)) {
                    continue
                }
                compat.cancel(status.id)
                cleared += 1
            }
        }
        return cleared
    }

    private fun matchesMsgKey(extras: Bundle, msgKey: String): Boolean {
        val direct = extras.getString("msgKey")?.trim().orEmpty()
        if (direct == msgKey) {
            return true
        }
        return extractMsgKeyFromJson(extras.getString("cn.jpush.android.EXTRA")) == msgKey ||
            extractMsgKeyFromJson(extras.getString("n_extra")) == msgKey
    }

    private fun extractMsgKeyFromJson(raw: String?): String {
        if (raw.isNullOrBlank()) {
            return ""
        }
        return try {
            JSONObject(raw).optString("msgKey").trim()
        } catch (_: Exception) {
            ""
        }
    }

    private fun isImChatNotification(notification: Notification, threadId: String): Boolean {
        val extras = notification.extras ?: return false
        val type = readTypeFromExtras(extras)
        if (type != "im_chat" && type != "chat_message") {
            if (notification.channelId != CHAT_CHANNEL_ID) {
                return false
            }
            return threadId.isEmpty()
        }
        if (threadId.isEmpty()) {
            return true
        }
        val payloadThread = readThreadIdFromExtras(extras)
        return payloadThread.isEmpty() || payloadThread == threadId
    }

    private fun readTypeFromExtras(extras: Bundle): String {
        val direct = extras.getString("type")?.trim()?.lowercase().orEmpty()
        if (direct.isNotEmpty()) {
            return direct
        }
        return extractTypeFromJson(extras.getString("cn.jpush.android.EXTRA"))
            .ifEmpty { extractTypeFromJson(extras.getString("n_extra")) }
    }

    private fun readThreadIdFromExtras(extras: Bundle): String {
        val direct = extras.getString("threadId")?.trim().orEmpty()
        if (direct.isNotEmpty()) {
            return direct
        }
        val chatType = extras.getString("chatType")?.trim()?.lowercase()
            ?: extras.getString("chat_type")?.trim()?.lowercase()
            ?: ""
        val groupId = extras.getString("groupId")?.trim()
            ?: extras.getString("groupID")?.trim()
            ?: extras.getString("group_id")?.trim()
            ?: ""
        if (chatType == "group" && groupId.isNotEmpty()) {
            return "group_$groupId"
        }
        val fromAccount = extras.getString("fromAccount")?.trim()
            ?: extras.getString("from_account")?.trim()
            ?: extras.getString("sender")?.trim()
            ?: ""
        if (fromAccount.isNotEmpty()) {
            return "c2c_$fromAccount"
        }
        return extractThreadFromJson(extras.getString("cn.jpush.android.EXTRA"))
            .ifEmpty { extractThreadFromJson(extras.getString("n_extra")) }
    }

    private fun extractTypeFromJson(raw: String?): String {
        if (raw.isNullOrBlank()) {
            return ""
        }
        return try {
            JSONObject(raw).optString("type").trim().lowercase()
        } catch (_: Exception) {
            ""
        }
    }

    private fun extractThreadFromJson(raw: String?): String {
        if (raw.isNullOrBlank()) {
            return ""
        }
        return try {
            val json = JSONObject(raw)
            val chatType = json.optString("chatType", json.optString("chat_type"))
                .trim()
                .lowercase()
            val groupId = json.optString("groupId", json.optString("groupID"))
                .trim()
            if (chatType == "group" && groupId.isNotEmpty()) {
                return "group_$groupId"
            }
            val fromAccount = json.optString("fromAccount", json.optString("sender"))
                .trim()
            if (fromAccount.isNotEmpty()) {
                "c2c_$fromAccount"
            } else {
                ""
            }
        } catch (_: Exception) {
            ""
        }
    }

    private fun showChatNotification(
        title: String,
        body: String,
        conversationID: String,
        ext: String,
        avatarUrl: String?,
        notificationId: Int?,
        msgKey: String?,
        threadId: String?,
    ): Boolean {
        ensureNotificationChannel()
        val intent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_CONVERSATION_ID, conversationID)
            putExtra(EXTRA_EXT, ext)
            putExtra(EXTRA_SOURCE, "android_local_notification")
        } ?: Intent(appContext, ChatNotificationClickReceiver::class.java).apply {
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_CONVERSATION_ID, conversationID)
            putExtra(EXTRA_EXT, ext)
            putExtra(EXTRA_SOURCE, "android_local_notification")
        }
        val resolvedId = notificationId
            ?: msgKey?.hashCode()?.and(0x7fffffff)
            ?: (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
        val pendingIntent = PendingIntent.getActivity(
            appContext,
            resolvedId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val largeIcon: Bitmap = try {
            Executors.newSingleThreadExecutor().submit(Callable<Bitmap> {
                NotificationAvatarLoader.load(appContext, avatarUrl)
            }).get(12, TimeUnit.SECONDS)
        } catch (_: Exception) {
            NotificationAvatarLoader.load(appContext, null)
        }
        val notification = NotificationCompat.Builder(appContext, CHAT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(largeIcon)
            .setContentTitle(title.ifBlank { appContext.getString(R.string.keep_alive_notification_title) })
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .apply {
                if (!threadId.isNullOrBlank()) {
                    setGroup(threadId)
                }
                if (!msgKey.isNullOrBlank()) {
                    setGroupSummary(false)
                }
            }
            .build()
        return try {
            NotificationManagerCompat.from(appContext).notify(resolvedId, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = appContext.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHAT_CHANNEL_ID,
            appContext.getString(R.string.chat_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = appContext.getString(R.string.chat_notification_channel_desc)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_CONVERSATION_ID = "conversationID"
        const val EXTRA_EXT = "ext"
        const val EXTRA_SOURCE = "source"
        private const val CHAT_CHANNEL_ID = "message_push_channel"
        private const val PREFS = "app_system_notification"
        private const val KEY_PENDING = "pending_click_json"

        @Volatile
        private var activeChannel: MethodChannel? = null

        fun storePendingClick(context: Context, payload: Map<String, String>) {
            val json = JSONObject()
            payload.forEach { (key, value) -> json.put(key, value) }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING, json.toString())
                .apply()
        }

        fun readPendingClick(context: Context, clear: Boolean): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, null) ?: return null
            if (clear) {
                prefs.edit().remove(KEY_PENDING).apply()
            }
            val json = JSONObject(raw)
            val result = linkedMapOf<String, Any?>()
            json.keys().forEach { key ->
                result[key] = json.optString(key)
            }
            return result
        }

        fun dispatchClick(context: Context, payload: Map<String, String>) {
            val flutterChannel = activeChannel ?: return
            val map = HashMap<String, Any?>()
            payload.forEach { (key, value) -> map[key] = value }
            flutterChannel.invokeMethod("onNotificationClicked", map)
        }

        fun payloadFromIntent(intent: Intent?): Map<String, String>? {
            if (intent == null) {
                return null
            }
            val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
            val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
            val conversationID = intent.getStringExtra(EXTRA_CONVERSATION_ID).orEmpty()
            val ext = intent.getStringExtra(EXTRA_EXT).orEmpty()
            if (title.isEmpty() && body.isEmpty() && conversationID.isEmpty() && ext.isEmpty()) {
                return null
            }
            return linkedMapOf(
                "title" to title,
                "body" to body,
                "conversationID" to conversationID,
                "ext" to ext,
                "source" to (intent.getStringExtra(EXTRA_SOURCE) ?: "android_local_notification"),
            )
        }
    }

    private fun readPendingClick(clear: Boolean): Map<String, Any?>? {
        return readPendingClick(appContext, clear)
    }
}
