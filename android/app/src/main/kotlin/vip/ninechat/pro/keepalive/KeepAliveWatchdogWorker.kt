package vip.ninechat.pro.keepalive

import android.content.Context
import androidx.work.Configuration
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class KeepAliveWatchdogWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        if (!KeepAliveForegroundService.isRunning(applicationContext)) {
            KeepAliveForegroundService.start(applicationContext, "watchdog")
        }
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "keep_alive_watchdog"

        fun schedule(context: Context) {
            val appContext = context.applicationContext
            ensureWorkManager(appContext)
            val request = PeriodicWorkRequestBuilder<KeepAliveWatchdogWorker>(
                15,
                TimeUnit.MINUTES,
            ).build()
            WorkManager.getInstance(appContext).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun cancel(context: Context) {
            val appContext = context.applicationContext
            ensureWorkManager(appContext)
            WorkManager.getInstance(appContext)
                .cancelUniqueWork(WORK_NAME)
        }

        private fun ensureWorkManager(context: Context) {
            try {
                WorkManager.getInstance(context)
            } catch (_: IllegalStateException) {
                WorkManager.initialize(
                    context,
                    Configuration.Builder().build(),
                )
            }
        }
    }
}
