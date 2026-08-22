import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_responsive.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 宽屏 / Web 弹窗尺寸约定：用 clamp 固定区间，避免 `width * 0.3` 过窄。
/// 仅影响桌面分支；移动端请继续用全页 / BottomSheet。
class DesktopModalLayout {
  DesktopModalLayout._();

  static double _scaledHeight(
    BuildContext context,
    double baseHeight,
    double minHeight,
    double maxHeight,
  ) {
    final extra = math.max(0.0, AppResponsive.textScale(context) - 1.0) * 64;
    return (baseHeight + extra).clamp(minHeight, maxHeight + extra).toDouble();
  }

  static bool isDesktop(BuildContext context) =>
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

  /// 通用中等弹窗（加好友、加群、搜索添加等）
  static Size medium(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(420, 520).toDouble(),
      _scaledHeight(context, size.height * 0.72, 480, 640),
    );
  }

  /// 选人 / 转发 / 群管理等大弹窗
  static Size large(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(560, 720).toDouble(),
      _scaledHeight(context, size.height * 0.78, 520, 720),
    );
  }

  /// 建群双栏选人
  static Size createGroupPicker(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(640, 860).toDouble(),
      _scaledHeight(context, size.height * 0.72, 520, 720),
    );
  }

  /// 共同群聊 / 朋友圈 / 聊天背景等左右内容弹窗
  static Size dualPane(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(720, 980).toDouble(),
      _scaledHeight(context, size.height * 0.82, 560, 780),
    );
  }

  /// 搜索历史等半宽弹窗
  static Size searchDetail(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(520, 720).toDouble(),
      _scaledHeight(context, size.height * 0.72, 480, 680),
    );
  }

  /// 确认 / 资料类紧凑弹窗
  static Size compact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(360, 440).toDouble(),
      _scaledHeight(context, size.height * 0.55, 320, 520),
    );
  }

  /// 个人/群二维码弹窗：控制高度，避免桌面视口内再滚动
  static Size qrCode(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(360, 420).toDouble(),
      _scaledHeight(context, size.height * 0.62, 420, 500),
    );
  }
}
