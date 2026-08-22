package vip.ninechat.pro

import android.app.Application
import androidx.work.Configuration
import androidx.work.WorkManager

/**
 * Initializes WorkManager for the main process and :keepalive.
 * better_player_plus and keepalive watchdog both require it; the default
 * WorkManagerInitializer is merged out by some dependencies.
 */
class ChatProApplication : Application(), Configuration.Provider {
    override fun onCreate() {
        super.onCreate()
        ensureWorkManagerInitialized()
    }

    private fun ensureWorkManagerInitialized() {
        try {
            WorkManager.getInstance(this)
        } catch (_: IllegalStateException) {
            WorkManager.initialize(this, workManagerConfiguration)
        }
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()
}
