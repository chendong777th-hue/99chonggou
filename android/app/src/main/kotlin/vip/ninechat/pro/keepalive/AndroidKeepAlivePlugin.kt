package vip.ninechat.pro.keepalive

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AndroidKeepAlivePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "android_keep_alive")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val reason = call.argument<String>("reason") ?: "manual"
                KeepAliveForegroundService.start(appContext, reason)
                KeepAliveWatchdogWorker.schedule(appContext)
                result.success(true)
            }

            "stop" -> {
                val reason = call.argument<String>("reason") ?: "manual"
                KeepAliveForegroundService.stop(appContext, reason)
                KeepAliveWatchdogWorker.cancel(appContext)
                result.success(true)
            }

            "isRunning" -> {
                result.success(KeepAliveForegroundService.isRunning(appContext))
            }

            else -> result.notImplemented()
        }
    }
}
