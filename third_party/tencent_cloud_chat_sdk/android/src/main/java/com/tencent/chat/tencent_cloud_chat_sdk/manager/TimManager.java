package com.tencent.chat.tencent_cloud_chat_sdk.manager;

import android.content.Context;
import android.util.Log;
import com.tencent.imsdk.common.IMContext;
import com.tencent.imsdk.common.NetworkInfoCenter;
import com.tencent.imsdk.common.SystemUtil;
import com.tencent.imsdk.manager.BaseManager;
import com.tencent.imsdk.v2.V2TIMValueCallback;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import org.json.JSONObject;

public class TimManager {
    public void getNetworkInfo(MethodCall methodCall, final MethodChannel.Result result) {
        HashMap<String, Object> networkInfo = new HashMap<String, Object>();
        networkInfo.put("networkType", NetworkInfoCenter.getInstance().getNetworkType());
        networkInfo.put("ipType", NetworkInfoCenter.getInstance().getIPType());
        networkInfo.put("networkId", NetworkInfoCenter.getInstance().getNetworkID());
        networkInfo.put("wifiNetworkHandle", NetworkInfoCenter.getInstance().getWifiNetworkHandle());
        networkInfo.put("xgNetworkHandle", NetworkInfoCenter.getInstance().getXgNetworkHandle());
        networkInfo.put("initializeCostTime", NetworkInfoCenter.getInstance().getInitializeCostTime());
        networkInfo.put("networkConnected", NetworkInfoCenter.getInstance().isNetworkConnected());

        result.success(networkInfo);
    }

    public void getDeviceInfo(MethodCall methodCall, final MethodChannel.Result result) {
        HashMap<String, Object> deviceInfo = new HashMap<String, Object>();
        deviceInfo.put("deviceType", SystemUtil.getDeviceType());
        deviceInfo.put("deviceBrand", SystemUtil.getInstanceType());
        deviceInfo.put("systemVersion", SystemUtil.getSystemVersion());

        result.success(deviceInfo);
    }

    public void getMainThreadLooperPointer(MethodCall methodCall, final MethodChannel.Result result) {
        IMContext.getInstance().runOnMainThread(new Runnable() {
            @Override
            public void run() {
                long mainLooperPointer = BaseManager.getInstance().getMainLooperPointer();
                HashMap<String, Object> mainThreadLooperPointMap = new HashMap<String, Object>();
                mainThreadLooperPointMap.put("mainThreadLooperPointer", mainLooperPointer);

                result.success(mainThreadLooperPointMap);
            }
        });
    }
}
