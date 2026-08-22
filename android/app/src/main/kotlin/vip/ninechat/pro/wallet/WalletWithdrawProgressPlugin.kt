package vip.ninechat.pro.wallet

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WalletWithdrawProgressPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "wallet_withdraw_progress")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = (call.arguments as? Map<*, *>)?.mapKeys { it.key.toString() }
            ?.mapValues { it.value } ?: emptyMap()
        when (call.method) {
            "start" -> {
                val activityId = WithdrawProgressForegroundService.start(appContext, args)
                result.success(
                    mapOf(
                        "activityId" to activityId,
                        "pushToken" to "",
                        "supported" to true,
                    ),
                )
            }
            "update" -> {
                WithdrawProgressForegroundService.update(appContext, args)
                result.success(true)
            }
            "end" -> {
                WithdrawProgressForegroundService.end(appContext, args)
                result.success(true)
            }
            "getActive" -> {
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
