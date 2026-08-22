package com.tencent.cloud.tuikit.flutter.tuicallkit.utils;

import android.app.AppOpsManager;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Build;

import com.tencent.qcloud.tuicore.TUIConfig;
import com.tencent.qcloud.tuicore.permission.PermissionRequester;
import com.trtc.tuikit.common.util.TUIBuild;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

public class Permission {
    public static boolean hasPermission(String premission) {
        return PermissionRequester.newInstance(premission).has();
    }

    public static void requestFloatPermission() {
        if (PermissionRequester.newInstance(PermissionRequester.FLOAT_PERMISSION).has()) {
            return;
        }
        //In TUICallKit,Please open both OverlayWindows and Background pop-ups permission.
        PermissionRequester.newInstance(PermissionRequester.FLOAT_PERMISSION, PermissionRequester.BG_START_PERMISSION)
                .request();
    }

    public static boolean isNotificationEnabled() {
        Context context = TUIConfig.getAppContext();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            return manager.areNotificationsEnabled();
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            AppOpsManager appOps = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
            ApplicationInfo appInfo = context.getApplicationInfo();
            String packageName = context.getPackageName();
            int uid = appInfo.uid;
            try {
                Class<?> appOpsClass = AppOpsManager.class;
                Method checkOpNoThrowMethod = appOpsClass.getMethod(
                        "checkOpNoThrow", int.class, int.class, String.class
                );
                Field opPostNotificationField = appOpsClass.getDeclaredField("OP_POST_NOTIFICATION");
                int value = opPostNotificationField.getInt(null);

                int result = (int) checkOpNoThrowMethod.invoke(appOps, value, uid, packageName);
                return result == AppOpsManager.MODE_ALLOWED;

            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return false;
    }
}
