package com.tencent.chat.tencent_cloud_chat_sdk;

import android.app.Application;
import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import com.tencent.chat.tencent_cloud_chat_sdk.manager.TimManager;
import com.tencent.imsdk.common.NetworkInfoCenter;
import com.tencent.imsdk.manager.BaseManager;
import com.tencent.imsdk.v2.V2TIMManager;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;

/** TencentCloudChatSdkPlugin */
public class TencentCloudChatSdkPlugin implements FlutterPlugin, MethodCallHandler {
    public static String TAG = "tencent_cloud_chat_sdk";

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;

    /**
   * global context
   */
    public static Context context;

    /**
   * Communication pipeline with Flutter
   */
    private static List<MethodChannel> channels = new LinkedList<>();
    public static TimManager timManager;

    private static HashMap<FlutterPluginBinding, MethodChannel> bindingToChannelMap = new HashMap<>();

    public TencentCloudChatSdkPlugin() {}

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "tencent_cloud_chat_sdk");
        TencentCloudChatSdkPlugin.context = flutterPluginBinding.getApplicationContext();
        TencentCloudChatSdkPlugin.channels.add(channel);
        TencentCloudChatSdkPlugin.timManager = new TimManager();
        channel.setMethodCallHandler(this);

        bindingToChannelMap.put(flutterPluginBinding, channel);

        // android 的 http 和 db 使用系统库，监听网络变化也需要通知 C++ engine，需要 jni 环境，
        // 这里通过 BaseManager 构造函数调用 System.loadLibrary 来初始化 jni 环境。
        NetworkInfoCenter.getInstance().init(flutterPluginBinding.getApplicationContext(), BaseManager.getInstance());
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        String managerName = "timManager";
        String apiname = call.method;

        Field field = null;
        Method method = null;
        try {
            field = TencentCloudChatSdkPlugin.class.getDeclaredField(managerName);
            method = field.get(new Object()).getClass().getDeclaredMethod(apiname, MethodCall.class, Result.class);
            method.invoke(field.get(new Object()), call, result);
            try {
                call.<HashMap<String, Object>>arguments().remove("stacktrace");
                call.<HashMap<String, Object>>arguments().put("method", apiname);
            } catch (Exception e) {
                System.out.println("print log error");
            }
        } catch (Exception e) {
            System.out.println("cant find method error:" + apiname);
            e.printStackTrace();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        MethodChannel targetChannel = bindingToChannelMap.remove(binding);
        if (targetChannel != null) {
            channels.remove(targetChannel);
            targetChannel.setMethodCallHandler(null);
        }
    }
}
