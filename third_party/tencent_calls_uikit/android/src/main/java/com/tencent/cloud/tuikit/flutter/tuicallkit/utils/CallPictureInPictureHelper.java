package com.tencent.cloud.tuikit.flutter.tuicallkit.utils;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.res.Configuration;
import android.os.Build;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import android.util.Rational;

import com.tencent.cloud.tuikit.engine.call.TUICallDefine;
import com.tencent.cloud.tuikit.flutter.tuicallkit.state.TUICallState;
import com.tencent.cloud.tuikit.flutter.tuicallkit.state.User;

import java.lang.ref.WeakReference;
import java.util.ArrayList;

/**
 * Enters Android system Picture-in-Picture during an active video call.
 */
public final class CallPictureInPictureHelper {
    public interface ForegroundNotifier {
        void notifyEnterForeground();
    }

    private static WeakReference<Activity> sActivityRef = new WeakReference<>(null);
    private static ForegroundNotifier sForegroundNotifier;
    private static boolean sInPictureInPictureMode = false;

    private CallPictureInPictureHelper() {
    }

    public static void setActivity(Activity activity) {
        sActivityRef = new WeakReference<>(activity);
        CallPipLogger.log("setActivity " + (activity == null ? "null" : activity.getClass().getSimpleName()));
    }

    public static void clearActivity(Activity activity) {
        Activity current = sActivityRef.get();
        if (activity == null || current == activity) {
            sActivityRef = new WeakReference<>(null);
            CallPipLogger.log("clearActivity");
        }
    }

    public static void setForegroundNotifier(ForegroundNotifier notifier) {
        sForegroundNotifier = notifier;
    }

    public static boolean isPictureInPictureSupported() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O;
    }

    public static boolean isInPictureInPictureMode() {
        return sInPictureInPictureMode;
    }

    public static String describeCallState() {
        TUICallState state = TUICallState.getInstance();
        ArrayList<User> remotes = state.mRemoteUserList;
        String remoteId = remotes.isEmpty() ? "" : remotes.get(0).id;
        return "status=" + state.mSelfUser.callStatus
                + " mediaType=" + state.mMediaType
                + " remoteId=" + remoteId
                + " remoteCount=" + remotes.size();
    }

    public static boolean shouldEnterPictureInPicture() {
        TUICallState state = TUICallState.getInstance();
        boolean ready = state.mSelfUser.callStatus == TUICallDefine.Status.Accept
                && state.mMediaType == TUICallDefine.MediaType.Video;
        if (!ready) {
            CallPipLogger.log("shouldEnterPictureInPicture=false " + describeCallState());
        }
        return ready;
    }

    public static void onUserLeaveHint(Activity activity) {
        CallPipLogger.log("onUserLeaveHint activity=" + (activity == null ? "null" : activity.getClass().getSimpleName()));
        enterPictureInPictureIfNeeded(activity);
    }

    public static void onPause(Activity activity) {
        if (activity == null || activity.isFinishing() || activity.isChangingConfigurations()) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity.isInPictureInPictureMode()) {
            return;
        }
        CallPipLogger.log("onPause fallback " + describeCallState());
        enterPictureInPictureIfNeeded(activity);
    }

    public static void enterPictureInPictureIfNeeded(Activity activity) {
        if (activity == null) {
            activity = sActivityRef.get();
        }
        if (activity == null) {
            activity = WakeLock.getInstance().getActivity();
        }
        if (activity == null) {
            CallPipLogger.error("enterPictureInPictureIfNeeded aborted: activity=null " + describeCallState());
            return;
        }
        boolean isResumed = !activity.isFinishing();
        if (activity instanceof LifecycleOwner) {
            isResumed = ((LifecycleOwner) activity).getLifecycle().getCurrentState().isAtLeast(Lifecycle.State.RESUMED);
        }
        CallPipLogger.log(
                "enterPictureInPictureIfNeeded activity="
                        + activity.getClass().getSimpleName()
                        + " resumed=" + isResumed
                        + " finishing=" + activity.isFinishing()
                        + " " + describeCallState()
        );
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            CallPipLogger.log("enterPictureInPictureIfNeeded aborted: API<26");
            return;
        }
        if (activity.isInPictureInPictureMode()) {
            CallPipLogger.log("enterPictureInPictureIfNeeded skipped: already in PiP");
            return;
        }
        if (!shouldEnterPictureInPicture()) {
            return;
        }
        if (!activity.getPackageManager().hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            CallPipLogger.error("enterPictureInPictureIfNeeded aborted: FEATURE_PICTURE_IN_PICTURE missing");
            return;
        }
        try {
            Rational aspectRatio = new Rational(9, 16);
            PictureInPictureParams.Builder builder =
                    new PictureInPictureParams.Builder().setAspectRatio(aspectRatio);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setAutoEnterEnabled(false);
                builder.setSeamlessResizeEnabled(true);
            }
            boolean entered = activity.enterPictureInPictureMode(builder.build());
            CallPipLogger.log("enterPictureInPictureMode result=" + entered + " " + describeCallState());
        } catch (IllegalStateException error) {
            CallPipLogger.error("enterPictureInPictureMode failed: " + error.getMessage() + " " + describeCallState());
        }
    }

    public static void onPictureInPictureModeChanged(boolean isInPictureInPictureMode) {
        sInPictureInPictureMode = isInPictureInPictureMode;
        CallPipLogger.log("onPictureInPictureModeChanged inPip=" + isInPictureInPictureMode);
        if (!isInPictureInPictureMode && sForegroundNotifier != null) {
            sForegroundNotifier.notifyEnterForeground();
        }
    }

    public static void onPictureInPictureModeChanged(
            boolean isInPictureInPictureMode,
            Configuration newConfig
    ) {
        onPictureInPictureModeChanged(isInPictureInPictureMode);
    }

    public static void onCallEnded() {
        sInPictureInPictureMode = false;
        CallPipLogger.log("onCallEnded");
    }
}


