package vip.ninechat.pro.wallet

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import vip.ninechat.pro.MainActivity
import vip.ninechat.pro.R

class WithdrawProgressForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val orderId = intent?.getStringExtra(EXTRA_ORDER_ID).orEmpty()
        val stage = intent?.getStringExtra(EXTRA_STAGE).orEmpty()
        val amountText = intent?.getStringExtra(EXTRA_AMOUNT_TEXT).orEmpty()
        val coin = intent?.getStringExtra(EXTRA_COIN).orEmpty()
        val confirmations = intent?.getIntExtra(EXTRA_CONFIRMATIONS, 0) ?: 0
        val requiredConfirmations =
            intent?.getIntExtra(EXTRA_REQUIRED_CONFIRMATIONS, 19) ?: 19

        ensureChannel()
        val notification = buildNotification(
            orderId = orderId,
            stage = stage,
            amountText = amountText,
            coin = coin,
            confirmations = confirmations,
            requiredConfirmations = requiredConfirmations,
            ongoing = intent?.action != ACTION_END,
        )
        startForeground(NOTIFICATION_ID, notification)
        if (intent?.action == ACTION_END) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
        return START_STICKY
    }

    private fun buildNotification(
        orderId: String,
        stage: String,
        amountText: String,
        coin: String,
        confirmations: Int,
        requiredConfirmations: Int,
        ongoing: Boolean,
    ): Notification {
        val title = stageLabel(stage)
        val body = progressBody(
            amountText = amountText,
            coin = coin,
            stage = stage,
            confirmations = confirmations,
            requiredConfirmations = requiredConfirmations,
        )
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ORDER_ID, orderId)
            putExtra(EXTRA_OPEN_WITHDRAW_DETAIL, true)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setProgress(
                progressMax(requiredConfirmations),
                progressValue(stage, confirmations, requiredConfirmations),
                stage != STAGE_COMPLETED && stage != STAGE_FAILED,
            )
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Withdraw progress",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "On-chain withdrawal progress"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "wallet_withdraw_progress"
        const val NOTIFICATION_ID = 91031

        const val ACTION_START = "vip.ninechat.pro.wallet.WITHDRAW_PROGRESS_START"
        const val ACTION_UPDATE = "vip.ninechat.pro.wallet.WITHDRAW_PROGRESS_UPDATE"
        const val ACTION_END = "vip.ninechat.pro.wallet.WITHDRAW_PROGRESS_END"
        const val ACTION_STOP = "vip.ninechat.pro.wallet.WITHDRAW_PROGRESS_STOP"

        const val EXTRA_ORDER_ID = "orderId"
        const val EXTRA_CLIENT_ORDER_ID = "clientOrderId"
        const val EXTRA_STAGE = "stage"
        const val EXTRA_AMOUNT_TEXT = "amountText"
        const val EXTRA_COIN = "coin"
        const val EXTRA_NETWORK = "network"
        const val EXTRA_CONFIRMATIONS = "confirmations"
        const val EXTRA_REQUIRED_CONFIRMATIONS = "requiredConfirmations"
        const val EXTRA_TX_HASH_SHORT = "txHashShort"
        const val EXTRA_ACTIVITY_ID = "activityId"
        const val EXTRA_OPEN_WITHDRAW_DETAIL = "openWithdrawDetail"

        const val STAGE_SUBMITTED = "SUBMITTED"
        const val STAGE_BROADCASTING = "BROADCASTING"
        const val STAGE_CONFIRMING = "CONFIRMING"
        const val STAGE_COMPLETED = "COMPLETED"
        const val STAGE_FAILED = "FAILED"

        fun start(context: Context, args: Map<String, Any?>): String {
            val orderId = args["orderId"]?.toString().orEmpty()
            val intent = baseIntent(context, ACTION_START).apply {
                putExtras(args)
            }
            context.startForegroundService(intent)
            return orderId.ifEmpty { "withdraw_progress" }
        }

        fun update(context: Context, args: Map<String, Any?>) {
            val intent = baseIntent(context, ACTION_UPDATE).apply {
                putExtras(args)
            }
            context.startForegroundService(intent)
        }

        fun end(context: Context, args: Map<String, Any?>) {
            val intent = baseIntent(context, ACTION_END).apply {
                putExtras(args)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = baseIntent(context, ACTION_STOP)
            context.startService(intent)
        }

        private fun baseIntent(context: Context, action: String): Intent {
            return Intent(context, WithdrawProgressForegroundService::class.java).apply {
                this.action = action
            }
        }

        private fun Intent.putExtras(args: Map<String, Any?>) {
            putExtra(EXTRA_ORDER_ID, args["orderId"]?.toString().orEmpty())
            putExtra(EXTRA_CLIENT_ORDER_ID, args["clientOrderId"]?.toString().orEmpty())
            putExtra(EXTRA_STAGE, args["stage"]?.toString().orEmpty())
            putExtra(EXTRA_AMOUNT_TEXT, args["amountText"]?.toString().orEmpty())
            putExtra(EXTRA_COIN, args["coin"]?.toString().orEmpty())
            putExtra(EXTRA_NETWORK, args["network"]?.toString().orEmpty())
            putExtra(EXTRA_CONFIRMATIONS, (args["confirmations"] as? Number)?.toInt() ?: 0)
            putExtra(
                EXTRA_REQUIRED_CONFIRMATIONS,
                (args["requiredConfirmations"] as? Number)?.toInt() ?: 19,
            )
            putExtra(EXTRA_TX_HASH_SHORT, args["txHashShort"]?.toString().orEmpty())
            putExtra(EXTRA_ACTIVITY_ID, args["activityId"]?.toString().orEmpty())
        }

        private fun stageLabel(stage: String): String {
            return when (stage.uppercase()) {
                STAGE_BROADCASTING -> "Broadcasting withdrawal"
                STAGE_CONFIRMING -> "Confirming withdrawal"
                STAGE_COMPLETED -> "Withdrawal completed"
                STAGE_FAILED -> "Withdrawal failed"
                else -> "Withdrawal submitted"
            }
        }

        private fun progressBody(
            amountText: String,
            coin: String,
            stage: String,
            confirmations: Int,
            requiredConfirmations: Int,
        ): String {
            val amount = listOf(amountText, coin).filter { it.isNotBlank() }.joinToString(" ")
            return when (stage.uppercase()) {
                STAGE_CONFIRMING ->
                    "$amount · Confirming $confirmations/$requiredConfirmations"
                STAGE_BROADCASTING -> "$amount · Broadcasting on chain"
                STAGE_COMPLETED -> "$amount · Completed"
                STAGE_FAILED -> "$amount · Failed"
                else -> "$amount · Submitted"
            }
        }

        private fun progressMax(requiredConfirmations: Int): Int {
            return requiredConfirmations.coerceAtLeast(1)
        }

        private fun progressValue(
            stage: String,
            confirmations: Int,
            requiredConfirmations: Int,
        ): Int {
            return when (stage.uppercase()) {
                STAGE_COMPLETED -> progressMax(requiredConfirmations)
                STAGE_FAILED -> 0
                STAGE_CONFIRMING -> confirmations.coerceIn(0, progressMax(requiredConfirmations))
                STAGE_BROADCASTING -> (progressMax(requiredConfirmations) * 0.2f).toInt()
                else -> (progressMax(requiredConfirmations) * 0.05f).toInt().coerceAtLeast(1)
            }
        }
    }
}
