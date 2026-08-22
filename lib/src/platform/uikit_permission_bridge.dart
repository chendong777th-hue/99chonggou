import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart' as uikit;

/// 将 UIKit 聊天媒体权限检查收口到 [PermissionGuard]。
class UikitPermissionBridge {
  UikitPermissionBridge._();

  static void install() {
    uikit.Permissions.onCheckPermission = _handle;
  }

  static Future<bool?> _handle(BuildContext context, int value) async {
    if (value == Permission.camera.value) {
      return PermissionGuard.cameraForPhoto(context);
    }
    if (value == Permission.microphone.value) {
      return PermissionGuard.microphoneForCall(context);
    }
    if (value == Permission.photosAddOnly.value) {
      return PermissionGuard.photosForSave(context);
    }
    if (value == Permission.photos.value) {
      return PermissionGuard.photosForPick(context);
    }
    if (value == Permission.videos.value) {
      return PermissionGuard.videosForPick(context);
    }
    if (value == Permission.storage.value) {
      return PermissionGuard.mediaForPick(context);
    }
    return null;
  }
}
