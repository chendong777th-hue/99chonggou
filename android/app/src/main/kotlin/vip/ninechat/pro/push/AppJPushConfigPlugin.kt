package vip.ninechat.pro.push

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import vip.ninechat.pro.logging.SilentLog as Log

class AppJPushConfigPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "android_jpush_config")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getConfig" -> {
                val config = readConfig()
                Log.d(
                    TAG,
                    "readJPushConfig packageName=${config["packageName"]} " +
                        "hasAppKey=${(config["appKey"] as String).isNotEmpty()} " +
                        "channel=${config["channel"]}",
                )
                result.success(config)
            }

            else -> result.notImplemented()
        }
    }

    private fun readConfig(): Map<String, String> {
        val packageName = appContext.packageName
        var appKey = ""
        var channel = "developer-default"
        try {
            val appInfo = appContext.packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val meta = appInfo.metaData
            appKey = meta?.getString("JPUSH_APPKEY")?.trim().orEmpty()
            channel = meta?.getString("JPUSH_CHANNEL")?.trim().orEmpty()
                .ifEmpty { "developer-default" }
        } catch (e: Exception) {
            Log.w(TAG, "readJPushConfig failed error=$e")
        }
        return mapOf(
            "packageName" to packageName,
            "appKey" to appKey,
            "channel" to channel,
        )
    }

    companion object {
        private const val TAG = "ExternalChatEntry"
    }
}
