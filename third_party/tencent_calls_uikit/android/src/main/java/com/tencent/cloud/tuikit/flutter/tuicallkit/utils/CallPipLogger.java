package com.tencent.cloud.tuikit.flutter.tuicallkit.utils;

import com.tencent.cloud.tuikit.flutter.tuicallkit.TUICallKitPlugin;

public final class CallPipLogger {
    private CallPipLogger() {
    }

    public static void log(String message) {
        Logger.info(TUICallKitPlugin.TAG, "[CallPip] " + message);
    }

    public static void error(String message) {
        Logger.error(TUICallKitPlugin.TAG, "[CallPip] " + message);
    }
}
