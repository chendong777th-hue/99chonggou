package vip.ninechat.pro.notification

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import vip.ninechat.pro.R
import java.net.HttpURLConnection
import java.net.URL

object NotificationAvatarLoader {
    fun load(context: Context, avatarUrl: String?): Bitmap {
        val remote = resolveAbsoluteUrl(avatarUrl?.trim().orEmpty())
        if (remote.isNotEmpty()) {
            try {
                val connection = URL(remote).openConnection() as HttpURLConnection
                connection.connectTimeout = 8000
                connection.readTimeout = 10000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("User-Agent", "99Chat/1.0")
                connection.inputStream.use { stream ->
                    BitmapFactory.decodeStream(stream)?.let { return it }
                }
            } catch (_: Exception) {
                // fall through to platform logo
            }
        }
        return BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
            ?: Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
    }

    private fun resolveAbsoluteUrl(raw: String): String {
        if (raw.isEmpty()) {
            return ""
        }
        if (raw.startsWith("http://") || raw.startsWith("https://")) {
            return raw
        }
        return raw
    }
}
