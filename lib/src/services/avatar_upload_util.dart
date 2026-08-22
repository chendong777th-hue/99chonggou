import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// 头像上传前规范化：统一压到头像展示友好的 JPEG，避免大图进入列表热路径。
class AvatarUploadUtil {
  AvatarUploadUtil._();

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const int _targetLongEdge = 640;
  static const int _minLongEdge = 384;
  static const int _targetMaxBytes = 220 * 1024;
  static const int _initialJpegQuality = 82;
  static const int _minJpegQuality = 70;

  static String? _extension(String path) {
    final name = path.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) {
      return null;
    }
    return name.substring(dot + 1).toLowerCase();
  }

  /// 返回可用于 multipart 上传的文件；失败返回 null。
  static Future<PreparedAvatarUpload?> prepare(File source) async {
    if (kIsWeb) {
      return null;
    }
    if (!await source.exists()) {
      return null;
    }

    final compressed = await _compressFileToJpeg(source);
    if (compressed != null) {
      return compressed;
    }

    final ext = _extension(source.path);
    if (ext == 'png') {
      return PreparedAvatarUpload(
        file: source,
        filename: 'avatar.png',
        mimeType: 'image/png',
        deleteAfterUpload: false,
      );
    }
    if (ext == 'webp') {
      return PreparedAvatarUpload(
        file: source,
        filename: 'avatar.webp',
        mimeType: 'image/webp',
        deleteAfterUpload: false,
      );
    }
    if (ext == 'jpg' || ext == 'jpeg') {
      return PreparedAvatarUpload(
        file: source,
        filename: 'avatar.jpg',
        mimeType: 'image/jpeg',
        deleteAfterUpload: false,
      );
    }

    return null;
  }

  /// Web / 桌面字节入口：尽量压缩；失败时退回原始字节，不阻断建群流程。
  static Future<PreparedAvatarBytes?> prepareBytes(
    List<int> source, {
    String filename = 'avatar.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    if (source.isEmpty) {
      return null;
    }
    final input = Uint8List.fromList(source);
    final compressed = await _compressBytesToJpeg(input);
    if (compressed != null && compressed.isNotEmpty) {
      return PreparedAvatarBytes(
        bytes: compressed,
        filename: 'avatar.jpg',
        mimeType: 'image/jpeg',
      );
    }
    return PreparedAvatarBytes(
      bytes: input,
      filename: filename,
      mimeType: mimeType,
    );
  }

  static Future<PreparedAvatarUpload?> _compressFileToJpeg(File source) async {
    try {
      final tempDir = await getTemporaryDirectory();
      var edge = _targetLongEdge;
      var quality = _initialJpegQuality;
      for (var attempt = 0; attempt < 5; attempt++) {
        final targetPath =
            '${tempDir.path}/avatar_upload_${DateTime.now().microsecondsSinceEpoch}_$attempt.jpg';
        final result = await FlutterImageCompress.compressAndGetFile(
          source.absolute.path,
          targetPath,
          minWidth: edge,
          minHeight: edge,
          quality: quality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        if (result == null) {
          continue;
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
        if (size <= _targetMaxBytes || attempt == 4) {
          return PreparedAvatarUpload(
            file: out,
            filename: 'avatar.jpg',
            mimeType: 'image/jpeg',
            deleteAfterUpload: true,
          );
        }
        await _deleteQuietly(out);
        if (quality > _minJpegQuality) {
          quality =
              (quality - 6).clamp(_minJpegQuality, _initialJpegQuality).toInt();
        } else {
          edge = (edge * 0.82)
              .round()
              .clamp(_minLongEdge, _targetLongEdge)
              .toInt();
          quality = 76;
        }
      }
    } catch (e) {
      debugPrint('AvatarUploadUtil: compress file failed ${source.path}: $e');
    }
    return null;
  }

  static Future<Uint8List?> _compressBytesToJpeg(Uint8List source) async {
    try {
      var edge = _targetLongEdge;
      var quality = _initialJpegQuality;
      for (var attempt = 0; attempt < 5; attempt++) {
        final result = await FlutterImageCompress.compressWithList(
          source,
          minWidth: edge,
          minHeight: edge,
          quality: quality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        if (result.isEmpty) {
          continue;
        }
        if (result.length <= _targetMaxBytes || attempt == 4) {
          return result;
        }
        if (quality > _minJpegQuality) {
          quality =
              (quality - 6).clamp(_minJpegQuality, _initialJpegQuality).toInt();
        } else {
          edge = (edge * 0.82)
              .round()
              .clamp(_minLongEdge, _targetLongEdge)
              .toInt();
          quality = 76;
        }
      }
    } catch (e) {
      debugPrint('AvatarUploadUtil: compress bytes failed: $e');
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

  static bool isAllowedExtension(String? ext) {
    if (ext == null || ext.isEmpty) {
      return false;
    }
    return _allowedExtensions.contains(ext.toLowerCase());
  }
}

class PreparedAvatarUpload {
  PreparedAvatarUpload({
    required this.file,
    required this.filename,
    required this.mimeType,
    required this.deleteAfterUpload,
  });

  final File file;
  final String filename;
  final String mimeType;
  final bool deleteAfterUpload;
}

class PreparedAvatarBytes {
  PreparedAvatarBytes({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}
