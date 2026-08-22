package vip.ninechat.pro.qr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max

/**
 * 相册扫码前：按 Exif 转正立，超大图等比缩小后写出 JPEG，供 Dart/zxing 解码。
 */
class QrImageNormalizePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var cacheDir: File? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cacheDir = binding.applicationContext.cacheDir
        channel = MethodChannel(binding.binaryMessenger, "qr_image_normalize")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cacheDir = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "normalize" -> normalize(call, result)
            else -> result.notImplemented()
        }
    }

    private fun normalize(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")?.trim().orEmpty()
        if (path.isEmpty()) {
            result.error("invalid_args", "path required", null)
            return
        }
        val maxSide = call.argument<Int>("maxSide") ?: 4096
        val quality = (call.argument<Int>("quality") ?: 92).coerceIn(50, 100)
        val src = File(path)
        if (!src.exists() || !src.isFile) {
            result.error("not_found", "image not found", null)
            return
        }

        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                result.error("decode_failed", "unable to decode image", null)
                return
            }

            val sample = computeInSampleSize(bounds.outWidth, bounds.outHeight, maxSide)
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            var bitmap = BitmapFactory.decodeFile(path, opts)
                ?: run {
                    result.error("decode_failed", "unable to decode image", null)
                    return
                }
            bitmap = applyExifRotation(path, bitmap)

            val longSide = max(bitmap.width, bitmap.height)
            if (longSide > maxSide) {
                val scale = maxSide.toFloat() / longSide.toFloat()
                val w = (bitmap.width * scale).toInt().coerceAtLeast(1)
                val h = (bitmap.height * scale).toInt().coerceAtLeast(1)
                val scaled = Bitmap.createScaledBitmap(bitmap, w, h, true)
                if (scaled !== bitmap) {
                    bitmap.recycle()
                    bitmap = scaled
                }
            }

            val outDir = File(cacheDir, "qr_norm").apply { mkdirs() }
            val outFile = File(outDir, "qr_${System.currentTimeMillis()}.jpg")
            FileOutputStream(outFile).use { fos ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, fos)) {
                    bitmap.recycle()
                    result.error("encode_failed", "jpeg compress failed", null)
                    return
                }
            }
            val width = bitmap.width
            val height = bitmap.height
            bitmap.recycle()
            result.success(
                mapOf(
                    "path" to outFile.absolutePath,
                    "width" to width,
                    "height" to height,
                    "isTemporary" to true,
                ),
            )
        } catch (e: Exception) {
            result.error("normalize_failed", e.message, null)
        }
    }

    private fun computeInSampleSize(width: Int, height: Int, maxSide: Int): Int {
        var sample = 1
        var w = width
        var h = height
        while (max(w, h) / (sample * 2) >= maxSide) {
            sample *= 2
        }
        return sample.coerceAtLeast(1)
    }

    private fun applyExifRotation(path: String, source: Bitmap): Bitmap {
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (degrees == 0f) {
            return source
        }
        val matrix = Matrix().apply { postRotate(degrees) }
        val rotated = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
        if (rotated !== source) {
            source.recycle()
        }
        return rotated
    }
}
