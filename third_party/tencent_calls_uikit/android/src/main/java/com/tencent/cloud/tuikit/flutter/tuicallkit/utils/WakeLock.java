package com.tencent.cloud.tuikit.flutter.tuicallkit.utils;

import android.app.Activity;
import android.content.Context;
import android.os.PowerManager;
import android.view.WindowManager;

public class WakeLock {
  public static final int POLICY_OFF = 0;
  public static final int POLICY_KEEP_AWAKE = 1;
  public static final int POLICY_PROXIMITY_EARPIECE = 2;

  private static WakeLock mInstance;
  private Activity mActivity;
  private int mCurrentPolicy = POLICY_OFF;
  private boolean mAppliedKeepScreenOn = false;
  private boolean mAppliedTurnScreenOn = false;
  private boolean mAppliedDismissKeyguard = false;
  private boolean mAppliedShowWhenLocked = false;
  private PowerManager.WakeLock mProximityWakeLock;

  private WakeLock() {}

  public static synchronized WakeLock getInstance() {
    if (mInstance == null) {
      mInstance = new WakeLock();
    }
    return mInstance;
  }

  public void setActivity(Activity activity) {
    this.mActivity = activity;
  }

  public Activity getActivity() {
    return mActivity;
  }

  public void enable() {
    applyPolicy(POLICY_KEEP_AWAKE);
  }

  public void disable() {
    applyPolicy(POLICY_OFF);
  }

  public void applyPolicy(int policy) {
    if (mCurrentPolicy == policy) {
      return;
    }
    mCurrentPolicy = policy;

    switch (policy) {
      case POLICY_OFF:
        releaseProximityWakeLock();
        clearAppliedWindowFlags();
        break;
      case POLICY_KEEP_AWAKE:
        releaseProximityWakeLock();
        applyKeepAwakeWindowFlags();
        break;
      case POLICY_PROXIMITY_EARPIECE:
        clearKeepScreenOnForProximity();
        applyLockScreenWindowFlags();
        acquireProximityWakeLock();
        break;
      default:
        applyPolicy(POLICY_OFF);
        break;
    }
  }

  private void applyKeepAwakeWindowFlags() {
    if (mActivity == null) {
      return;
    }
    final int flags = mActivity.getWindow().getAttributes().flags;
    if ((flags & WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
      mAppliedKeepScreenOn = true;
    }
    if ((flags & WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
      mAppliedTurnScreenOn = true;
    }
    if ((flags & WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
      mAppliedDismissKeyguard = true;
    }
    if ((flags & WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED);
      mAppliedShowWhenLocked = true;
    }
  }

  private void applyLockScreenWindowFlags() {
    if (mActivity == null) {
      return;
    }
    final int flags = mActivity.getWindow().getAttributes().flags;
    if ((flags & WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
      mAppliedTurnScreenOn = true;
    }
    if ((flags & WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
      mAppliedDismissKeyguard = true;
    }
    if ((flags & WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED) == 0) {
      mActivity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED);
      mAppliedShowWhenLocked = true;
    }
  }

  private void clearKeepScreenOnForProximity() {
    if (mActivity == null) {
      return;
    }
    mActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    mAppliedKeepScreenOn = false;
  }

  private void clearAppliedWindowFlags() {
    if (mActivity == null) {
      return;
    }
    if (mAppliedKeepScreenOn) {
      mActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
      mAppliedKeepScreenOn = false;
    }
    if (mAppliedTurnScreenOn) {
      mActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
      mAppliedTurnScreenOn = false;
    }
    if (mAppliedDismissKeyguard) {
      mActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
      mAppliedDismissKeyguard = false;
    }
    if (mAppliedShowWhenLocked) {
      mActivity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED);
      mAppliedShowWhenLocked = false;
    }
  }

  private void acquireProximityWakeLock() {
    if (mActivity == null) {
      return;
    }
    if (mProximityWakeLock != null && mProximityWakeLock.isHeld()) {
      return;
    }
    final PowerManager powerManager =
        (PowerManager) mActivity.getSystemService(Context.POWER_SERVICE);
    if (powerManager == null) {
      return;
    }
    mProximityWakeLock =
        powerManager.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "TUICallKit:Proximity");
    mProximityWakeLock.acquire();
  }

  private void releaseProximityWakeLock() {
    if (mProximityWakeLock != null && mProximityWakeLock.isHeld()) {
      mProximityWakeLock.release();
    }
    mProximityWakeLock = null;
  }
}
