package vip.ninechat.pro

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.util.Rational
import java.lang.ref.WeakReference

/**
 * LiveKit video-call system PiP (replaces TUICallKit state-gated helper).
 *
 * [pipEligible] = video call connected.
 * [pipContentReady] = fullscreen call page is showing video (not chat/float).
 * Native leave-hint only enters PiP when both are true, so the snapshot is video.
 */
object LiveKitCallPipHelper {
    private const val TAG = "LiveKitCallPip"

    @Volatile
    var pipEligible: Boolean = false

    @Volatile
    var pipContentReady: Boolean = false

    private var activityRef = WeakReference<Activity>(null)

    fun setActivity(activity: Activity?) {
        activityRef = WeakReference(activity)
    }

    fun clearActivity(activity: Activity?) {
        val current = activityRef.get()
        if (activity == null || current === activity) {
            activityRef = WeakReference(null)
        }
    }

    fun enterPictureInPictureIfNeeded(activity: Activity? = null): Boolean {
        if (!pipEligible) {
            Log.d(TAG, "skip: not eligible")
            return false
        }
        if (!pipContentReady) {
            Log.d(TAG, "skip: content not ready (call page not showing)")
            return false
        }
        val act = activity ?: activityRef.get() ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!act.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            return false
        }
        if (act.isInPictureInPictureMode) return true
        if (act.isFinishing) return false
        return try {
            val builder = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Auto-enter only when call page is ready — avoids chat-list snapshot.
                builder.setAutoEnterEnabled(true)
                builder.setSeamlessResizeEnabled(true)
            }
            val entered = act.enterPictureInPictureMode(builder.build())
            Log.d(TAG, "enterPictureInPictureMode result=$entered")
            entered
        } catch (e: IllegalStateException) {
            Log.e(TAG, "enterPictureInPictureMode failed: ${e.message}")
            false
        }
    }

    fun onCallEnded() {
        pipEligible = false
        pipContentReady = false
    }
}
