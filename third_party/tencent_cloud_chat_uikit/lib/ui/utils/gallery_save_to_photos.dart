import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 写入系统相册：iOS 上避免 [ImageGallerySaverPlus.saveFile] 带入 EXIF 旧拍摄时间，
/// 否则选图网格会按 creationDate 排到「上方旧图区」，与其它 App 刚存的新图不一致。
class GallerySaveToPhotos {
  GallerySaveToPhotos._();

  static bool get _avoidSaveFileOnIos =>
      !kIsWeb && PlatformUtils().isIOS;

  static Future<bool> saveBytes(
    Uint8List bytes, {
    required String name,
    int quality = 100,
  }) async {
    if (bytes.isEmpty) {
      return false;
    }
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: quality,
        name: name,
      );
      if (_isSuccess(result)) {
        return true;
      }
    } catch (_) {}

    if (_avoidSaveFileOnIos) {
      return false;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final result = await ImageGallerySaverPlus.saveFile(file.path);
      return _isSuccess(result);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveFile(
    File file, {
    required String name,
    int quality = 100,
  }) async {
    if (!file.existsSync()) {
      return false;
    }
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        return saveBytes(
          Uint8List.fromList(bytes),
          name: name,
          quality: quality,
        );
      }
    } catch (_) {}

    if (_avoidSaveFileOnIos) {
      return false;
    }

    try {
      final result = await ImageGallerySaverPlus.saveFile(file.path);
      return _isSuccess(result);
    } catch (_) {
      return false;
    }
  }

  static bool _isSuccess(dynamic result) {
    if (result == null) {
      return false;
    }
    if (result is bool) {
      return result;
    }
    if (result is num) {
      return result == 100 || result == 1 || result == 0;
    }
    if (result is String) {
      final value = result.trim().toLowerCase();
      if (value.isEmpty) {
        return false;
      }
      if (value.contains('fail') || value.contains('error')) {
        return false;
      }
      return true;
    }
    if (result is Map) {
      final success = result['isSuccess'] ?? result['success'];
      if (success is bool) {
        return success;
      }
      final code = result['returnCode'] ?? result['resultCode'] ?? result['code'];
      if (code is num) {
        return code == 100 || code == 1 || code == 0;
      }
    }
    return true;
  }
}
