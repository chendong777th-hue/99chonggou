import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_save_to_photos.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 将编辑后的图片保存到系统相册（微信：编辑完成写入相册，不自动发送）。
class EditedImageGallerySave {
  EditedImageGallerySave._();

  static Future<bool> save(BuildContext context, File file) async {
    if (!PlatformUtils().isMobile) {
      return false;
    }
    if (!await file.exists()) {
      return false;
    }
    if (!await _ensurePermission(context)) {
      return false;
    }
    return GallerySaveToPhotos.saveFile(
      file,
      name: 'edited_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<bool> _ensurePermission(BuildContext context) async {
    if (PlatformUtils().isIOS) {
      return Permissions.checkPermission(
        context,
        Permission.photosAddOnly.value,
        TUITheme(),
        false,
      );
    }
    if (PlatformUtils().isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 29) {
        return Permissions.checkPermission(
          context,
          Permission.storage.value,
        );
      }
    }
    return true;
  }
}
