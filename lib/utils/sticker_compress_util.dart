import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// 自定义表情上传前压缩：按原图比例缩边并转 PNG，不裁切；GIF 保持原样。
///
/// 后端当前使用 Java ImageIO 解码静态图，部分运行环境不支持 WebP，
/// 所以前端上传前统一把 WebP/压缩后的静态图转成 PNG。
class StickerCompressUtil {
  StickerCompressUtil._();

  static const int staticMaxBytes = 2 * 1024 * 1024;
  static const int gifMaxBytes = 5 * 1024 * 1024;

  /// 长边上限：偏清晰（约 2× 旧 480），仍控制体积。
  static const int maxLongEdge = 960;

  /// 小于此体积且边长已合格时跳过重压，避免无谓转码糊化。
  static const int skipCompressBelowBytes = 900 * 1024;

  static Future<CompressedStickerFile?> compressForUpload(
    File source, {
    required bool isGif,
  }) async {
    if (kIsWeb || !await source.exists()) {
      return null;
    }

    if (isGif) {
      return CompressedStickerFile(
        file: source,
        deleteAfterUpload: false,
        isGif: true,
      );
    }

    final originalSize = await source.length();
    final needsBackendCompatibleTranscode = _looksWebp(source.path);
    final imageSize = await _readImageSize(source);
    final needsResize = imageSize != null &&
        (imageSize.width > maxLongEdge || imageSize.height > maxLongEdge);
    final needsCompress = originalSize > skipCompressBelowBytes ||
        needsBackendCompatibleTranscode;

    if (!needsResize && !needsCompress) {
      return CompressedStickerFile(
        file: source,
        deleteAfterUpload: false,
        isGif: false,
      );
    }

    final compressed = await _compressStaticImage(
      source,
      imageSize: imageSize,
    );
    if (compressed == null) {
      if (needsBackendCompatibleTranscode) {
        return null;
      }
      return CompressedStickerFile(
        file: source,
        deleteAfterUpload: false,
        isGif: false,
      );
    }

    final compressedSize = await compressed.length();
    if (compressedSize <= 0) {
      await _deleteQuietly(compressed);
      if (needsBackendCompatibleTranscode) {
        return null;
      }
      return CompressedStickerFile(
        file: source,
        deleteAfterUpload: false,
        isGif: false,
      );
    }

    if (!needsBackendCompatibleTranscode &&
        compressedSize >= originalSize &&
        originalSize <= staticMaxBytes) {
      await _deleteQuietly(compressed);
      return CompressedStickerFile(
        file: source,
        deleteAfterUpload: false,
        isGif: false,
      );
    }

    return CompressedStickerFile(
      file: compressed,
      deleteAfterUpload: true,
      isGif: false,
    );
  }

  static bool _looksWebp(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.webp') || lower.contains('.webp?');
  }

  static Future<ui.Size?> _readImageSize(File source) async {
    try {
      final bytes = await source.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StickerCompressUtil: read size failed ${source.path}: $e');
      }
      return null;
    }
  }

  /// 按原图宽高比计算目标尺寸（仅缩小长边，不裁切）。
  static ({int width, int height}) _targetSizeForLongEdge(
    double width,
    double height,
    int maxEdge,
  ) {
    if (width <= maxEdge && height <= maxEdge) {
      return (
        width: width.round().clamp(1, maxEdge),
        height: height.round().clamp(1, maxEdge),
      );
    }
    if (width >= height) {
      final targetW = maxEdge;
      final targetH = (height * maxEdge / width).round().clamp(1, maxEdge);
      return (width: targetW, height: targetH);
    }
    final targetH = maxEdge;
    final targetW = (width * maxEdge / height).round().clamp(1, maxEdge);
    return (width: targetW, height: targetH);
  }

  static Future<File?> _compressStaticImage(
    File source, {
    ui.Size? imageSize,
  }) async {
    final tempDir = await getTemporaryDirectory();
    // PNG 仍走 quality 参数；起点偏高，避免首轮就糊。
    var quality = 95;
    var edge = maxLongEdge;

    final baseW = imageSize?.width ?? edge.toDouble();
    final baseH = imageSize?.height ?? edge.toDouble();

    for (var attempt = 0; attempt < 6; attempt++) {
      final target = _targetSizeForLongEdge(baseW, baseH, edge);
      final targetPath =
          '${tempDir.path}/sticker_upload_${DateTime.now().microsecondsSinceEpoch}.png';
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          source.absolute.path,
          targetPath,
          minWidth: target.width,
          minHeight: target.height,
          quality: quality,
          format: CompressFormat.png,
          keepExif: false,
        );
        if (result == null) {
          break;
        }
        final out = File(result.path);
        if (!await out.exists()) {
          continue;
        }
        final size = await out.length();
        if (size <= 0) {
          await _deleteQuietly(out);
          continue;
        }
        if (size <= staticMaxBytes) {
          return out;
        }
        await _deleteQuietly(out);
        quality -= 5;
        if (quality < 80) {
          // 体积仍超标再缩边，底线高于旧版 240，减少糊感。
          edge = (edge * 0.88).round().clamp(720, maxLongEdge);
          quality = 90;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StickerCompressUtil: compress failed ${source.path}: $e');
        }
        break;
      }
    }
    return null;
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class CompressedStickerFile {
  CompressedStickerFile({
    required this.file,
    required this.deleteAfterUpload,
    required this.isGif,
  });

  final File file;
  final bool deleteAfterUpload;
  final bool isGif;
}
