package com.fluttercandies.photo_manager.thumb

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Size
import com.bumptech.glide.Glide
import com.bumptech.glide.Priority
import com.bumptech.glide.request.FutureTarget
import com.bumptech.glide.request.RequestOptions
import com.bumptech.glide.signature.ObjectKey
import com.fluttercandies.photo_manager.core.entity.AssetEntity
import com.fluttercandies.photo_manager.core.entity.ThumbLoadOption
import com.fluttercandies.photo_manager.util.ResultHandler
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

object ThumbnailUtil {
    private const val GLIDE_TIMEOUT_MS = 1500L

    fun getThumbnail(
        context: Context,
        entity: AssetEntity,
        width: Int,
        height: Int,
        format: Bitmap.CompressFormat,
        quality: Int,
        frame: Long,
        resultHandler: ResultHandler
    ) {
        try {
            val resource = loadBitmap(context, entity, width, height, frame)
                ?: throw IllegalStateException("empty thumbnail bitmap")
            val bos = ByteArrayOutputStream()
            resource.compress(format, quality, bos)
            resultHandler.reply(bos.toByteArray())
        } catch (e: Exception) {
            resultHandler.replyError("Thumbnail request error", e.toString())
        }
    }

    private fun loadBitmap(
        context: Context,
        entity: AssetEntity,
        width: Int,
        height: Int,
        frame: Long,
    ): Bitmap? {
        loadWithGlide(context, entity.getUri(), width, height, frame, entity.modifiedDate)
            ?.let { return it }
        loadWithContentResolver(context, entity.getUri(), width, height)?.let { return it }

        // HarmonyOS / some OEM MediaStore URIs fail or hang in Glide,
        // while the file path used by send still works.
        val path = entity.path
        if (path.isNotEmpty()) {
            val file = File(path)
            if (file.exists()) {
                loadWithGlide(context, file, width, height, frame, entity.modifiedDate)
                    ?.let { return it }
                decodeFileScaled(file, width, height)?.let { return it }
            }
        }
        return null
    }

    private fun loadWithGlide(
        context: Context,
        model: Any,
        width: Int,
        height: Int,
        frame: Long,
        modifiedDate: Long,
    ): Bitmap? {
        return try {
            Glide.with(context)
                .asBitmap()
                .apply(RequestOptions().frame(frame).priority(Priority.IMMEDIATE))
                .load(model)
                .signature(ObjectKey(modifiedDate))
                .submit(width, height)
                .get(GLIDE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            null
        }
    }

    private fun loadWithContentResolver(
        context: Context,
        uri: Uri,
        width: Int,
        height: Int,
    ): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return null
        }
        return try {
            context.contentResolver.loadThumbnail(
                uri,
                Size(width.coerceAtLeast(1), height.coerceAtLeast(1)),
                null,
            )
        } catch (_: Exception) {
            decodeUriScaled(context, uri, width, height)
        }
    }

    private fun decodeUriScaled(
        context: Context,
        uri: Uri,
        width: Int,
        height: Int,
    ): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input, null, bounds)
            }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                return null
            }
            val sample = max(
                1,
                min(
                    bounds.outWidth / width.coerceAtLeast(1),
                    bounds.outHeight / height.coerceAtLeast(1),
                ),
            )
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            context.contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input, null, opts)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun decodeFileScaled(file: File, width: Int, height: Int): Bitmap? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.absolutePath, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                return null
            }
            val targetW = width.coerceAtLeast(1)
            val targetH = height.coerceAtLeast(1)
            val sample = max(
                1,
                min(bounds.outWidth / targetW, bounds.outHeight / targetH),
            )
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            BitmapFactory.decodeFile(file.absolutePath, opts)
        } catch (_: Exception) {
            null
        }
    }

    fun requestCacheThumb(
        context: Context,
        uri: Uri,
        thumbLoadOption: ThumbLoadOption
    ): FutureTarget<Bitmap> {
        return Glide.with(context)
            .asBitmap()
            .apply(RequestOptions().frame(thumbLoadOption.frame).priority(Priority.LOW))
            .load(uri)
            .submit(thumbLoadOption.width, thumbLoadOption.height)
    }

    fun requestCacheThumb(
        context: Context,
        path: String,
        thumbLoadOption: ThumbLoadOption
    ): FutureTarget<Bitmap> {
        return Glide.with(context)
            .asBitmap()
            .apply(RequestOptions().frame(thumbLoadOption.frame).priority(Priority.LOW))
            .load(path)
            .submit(thumbLoadOption.width, thumbLoadOption.height)
    }

    fun clearCache(context: Context) {
        Glide.get(context).apply { clearDiskCache() }
    }
}
