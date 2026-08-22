package vip.ninechat.pro.push

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Compatibility stub for old JPush common service registration.
 *
 * The current dependency set does not expose cn.jpush.android.service.JCommonService,
 * so extending that class breaks release Kotlin compilation. Keeping this no-op
 * Android Service lets existing AndroidManifest registrations compile safely while
 * preserving package/class name compatibility.
 */
class AppJCommonService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }
}
