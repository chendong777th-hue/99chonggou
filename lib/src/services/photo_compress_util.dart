import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// 相册同步前压缩图片，减小上传体积。
class PhotoCompressUtil {
  PhotoCompressUtil._();

  static const int maxLongEdge = 1920;
  static const int jpegQuality = 82;
  static const int skipCompressBelowBytes = 350 * 1024;

  /// 返回用于上传的文件；[deleteAfterUpload] 为 true 时上传后需删除临时文件。
  static Future<CompressedPhotoFile?> compressForUpload(File source) async {
    if (kIsWeb) {
      return null;
    }
    final ext = source.path.split('.').last.toLowerCase();
    if (ext == 'gif') {
      return CompressedPhotoFile(
        file: source,
        deleteAfterUpload: false,
        mimeType: 'image/gif',
      );
    }

    try {
      final originSize = await source.length();
      final isJpeg = ext == 'jpg' || ext == 'jpeg';
      if (isJpeg && originSize <= skipCompressBelowBytes) {
        return CompressedPhotoFile(
          file: source,
          deleteAfterUpload: false,
          mimeType: 'image/jpeg',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/sync_photo_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        targetPath,
        minWidth: maxLongEdge,
        minHeight: maxLongEdge,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (result == null) {
        return null;
      }
      final out = File(result.path);
      if (!await out.exists() || await out.length() <= 0) {
        return null;
      }
      return CompressedPhotoFile(
        file: out,
        deleteAfterUpload: true,
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      debugPrint('PhotoCompressUtil: compress failed ${source.path}: $e');
      return null;
    }
  }
}

class CompressedPhotoFile {
  CompressedPhotoFile({
    required this.file,
    required this.deleteAfterUpload,
    required this.mimeType,
  });

  final File file;
  final bool deleteAfterUpload;
  final String mimeType;
}
