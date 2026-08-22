import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';

/// 音视频通话权限收口。
class CallPlatform {
  CallPlatform._();

  static Future<bool> ensurePermissions(
    BuildContext context, {
    required bool video,
  }) {
    return PermissionGuard.call(context, video: video);
  }
}
