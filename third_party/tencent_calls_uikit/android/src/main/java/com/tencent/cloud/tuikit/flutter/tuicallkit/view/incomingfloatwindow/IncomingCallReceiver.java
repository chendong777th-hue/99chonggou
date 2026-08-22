package com.tencent.cloud.tuikit.flutter.tuicallkit.view.incomingfloatwindow;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.tencent.cloud.tuikit.flutter.tuicallkit.TUICallKitPlugin;
import com.tencent.cloud.tuikit.flutter.tuicallkit.utils.Constants;
import com.tencent.cloud.tuikit.flutter.tuicallkit.utils.Logger;
import com.tencent.qcloud.tuicore.TUICore;

import java.util.HashMap;
import java.util.Objects;

public class IncomingCallReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            Logger.warning(TUICallKitPlugin.TAG, "intent is invalid,ignore");
            return;
        }

        Logger.info(TUICallKitPlugin.TAG, "onReceive: action: " + intent.getAction());
        String callId = intent.getStringExtra("callId");
        IncomingNotificationView notificationView = IncomingNotificationView.getInstance(context);
        if (callId == null || !callId.equals(notificationView.getActiveCallId())) {
            Logger.warning(TUICallKitPlugin.TAG, "ignore stale notification action callId:" + callId);
            return;
        }

        if (Objects.equals(intent.getAction(), Constants.SUB_KEY_HANDLE_CALL_RECEIVED)) {
            notificationView.cancelNotification(callId);
            TUICore.notifyEvent(Constants.KEY_CALLKIT_PLUGIN, Constants.SUB_KEY_HANDLE_CALL_RECEIVED, null);
        } else if (Objects.equals(intent.getAction(), Constants.ACCEPT_CALL_ACTION)) {
            notifyFlutterAction("accept", callId);
        } else if (Objects.equals(intent.getAction(), Constants.REJECT_CALL_ACTION)) {
            notifyFlutterAction("reject", callId);
        } else {
            Logger.warning(TUICallKitPlugin.TAG, "intent.action is invalid,ignore");
        }
    }

    private void notifyFlutterAction(String action, String callId) {
        HashMap<String, Object> params = new HashMap<>();
        params.put("action", action);
        params.put("callId", callId);
        TUICore.notifyEvent(
                Constants.KEY_CALLKIT_PLUGIN,
                Constants.SUB_KEY_NOTIFICATION_CALL_ACTION,
                params);
    }
}
