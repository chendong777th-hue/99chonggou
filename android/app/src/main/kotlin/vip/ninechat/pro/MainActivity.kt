package vip.ninechat.pro

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.provider.Settings
import vip.ninechat.pro.battery.AndroidBatteryOptimizationPlugin
import vip.ninechat.pro.keepalive.AndroidKeepAlivePlugin
import vip.ninechat.pro.notification.AppSystemNotificationPlugin
import vip.ninechat.pro.push.AppJPushConfigPlugin
import vip.ninechat.pro.qr.QrImageNormalizePlugin
import vip.ninechat.pro.share.WalletSharePlugin
import vip.ninechat.pro.wallet.WalletWithdrawProgressPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var liveKitChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        LiveKitCallPipHelper.setActivity(this)
        handleNotificationIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        LiveKitCallPipHelper.setActivity(this)
    }

    override fun onDestroy() {
        LiveKitCallPipHelper.clearActivity(this)
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        LiveKitCallPipHelper.enterPictureInPictureIfNeeded(this)
    }

    override fun onPause() {
        super.onPause()
        if (!isChangingConfigurations) {
            LiveKitCallPipHelper.enterPictureInPictureIfNeeded(this)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        liveKitChannel?.invokeMethod(
            "onPipModeChanged",
            mapOf("isInPictureInPictureMode" to isInPictureInPictureMode),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AndroidKeepAlivePlugin())
        flutterEngine.plugins.add(AppJPushConfigPlugin())
        flutterEngine.plugins.add(AppSystemNotificationPlugin())
        flutterEngine.plugins.add(AndroidBatteryOptimizationPlugin())
        flutterEngine.plugins.add(WalletSharePlugin())
        flutterEngine.plugins.add(QrImageNormalizePlugin())
        flutterEngine.plugins.add(WalletWithdrawProgressPlugin())
        liveKitChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "livekit_call_platform",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipEligible" -> {
                        val eligible = call.argument<Boolean>("eligible") ?: false
                        LiveKitCallPipHelper.pipEligible = eligible
                        if (!eligible) {
                            LiveKitCallPipHelper.onCallEnded()
                        }
                        result.success(null)
                    }
                    "setPipContentReady" -> {
                        LiveKitCallPipHelper.pipContentReady =
                            call.argument<Boolean>("ready") ?: false
                        result.success(null)
                    }
                    "enterPictureInPicture" -> {
                        val entered =
                            LiveKitCallPipHelper.enterPictureInPictureIfNeeded(this)
                        result.success(entered)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "group_live_cast",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCastSettings" -> {
                    val intents = listOf(
                        Intent("android.settings.CAST_SETTINGS"),
                        Intent(Settings.ACTION_CAST_SETTINGS),
                        Intent(Settings.ACTION_WIFI_SETTINGS),
                    )
                    var opened = false
                    for (intent in intents) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                            opened = true
                            break
                        } catch (_: Exception) {
                            // try next
                        }
                    }
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "android_performance_profile",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPerformanceProfile" -> {
                    val manager = getSystemService(Context.ACTIVITY_SERVICE)
                        as? ActivityManager
                    result.success(
                        mapOf(
                            "memoryClass" to (manager?.memoryClass ?: 0),
                            "isLowRamDevice" to (manager?.isLowRamDevice ?: false),
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val payload = AppSystemNotificationPlugin.payloadFromIntent(intent) ?: return
        AppSystemNotificationPlugin.storePendingClick(applicationContext, payload)
        AppSystemNotificationPlugin.dispatchClick(applicationContext, payload)
    }
}
