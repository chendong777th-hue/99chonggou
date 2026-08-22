import 'dart:math' as math;

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 聊天内红包 / 转账 / 名片卡片尺寸：移动端走 ScreenUtil，Web 宽/高分轨缩放。
abstract final class ChatWalletCardMetrics {
  ChatWalletCardMetrics._();

  static const double designMaxWidth = 340;
  static const double designMinWidth = 180;
  static const double designMinCardHeight = 156;
  /// 脚栏块设计高度：上下 padding 8+8 + 一行脚栏字约 24。
  static const double designFooterBlockHeight = 40;
  static const double designIconSize = 68;

  /// Web 横向（宽度、字号、圆角）。
  static const double webWidthScale = 0.82;

  /// Web 纵向基准（高度、竖向内边距），与宽度分轨避免改宽时拉高卡片。
  static const double webHeightScale = 0.72;

  /// Web 纵向额外压缩。
  static const double webVerticalScale = 0.68;

  /// Web 卡片正文字号额外压缩（红包/转账/名片内文）。
  static const double webCardTextScale = 0.78;

  static bool get isWeb => PlatformUtils().isWeb;

  static double get maxWidth =>
      isWeb ? designMaxWidth * webWidthScale : designMaxWidth;

  static double get minWidth =>
      isWeb ? designMinWidth * webWidthScale : designMinWidth;

  static double get minCardHeight => isWeb
      ? designMinCardHeight * webHeightScale * webVerticalScale
      : designMinCardHeight.h;

  static double get footerBlockHeight => isWeb
      ? designFooterBlockHeight * webHeightScale * webVerticalScale
      : designFooterBlockHeight.h;

  /// 内容区最小高度，保证整卡 ≥ [minCardHeight] 且脚栏贴底。
  static double get minBodyHeight {
    final value = minCardHeight - footerBlockHeight;
    return value > 0 ? value : 0;
  }

  static double desktopMaxWidthForChat() => maxWidth;

  static double clampCardWidth(double parentMax) {
    if (!parentMax.isFinite || parentMax <= 0) {
      return maxWidth;
    }
    return math.min(maxWidth, math.max(minWidth, parentMax));
  }

  static double w(num value) =>
      isWeb ? value.toDouble() * webWidthScale : value.w;

  static double h(num value) => isWeb
      ? value.toDouble() * webHeightScale * webVerticalScale
      : value.h;

  static double sp(num value) =>
      isWeb ? value.toDouble() * webWidthScale : value.sp;

  static double r(num value) =>
      isWeb ? value.toDouble() * webWidthScale : value.r;

  static double iconSize([num design = designIconSize]) => isWeb
      ? design.toDouble() * webHeightScale * 0.78
      : design.w;

  static double footerSp([num design = 18]) => isWeb
      ? design.toDouble() * webHeightScale * 0.92
      : design.sp;

  /// 卡片主体文案（标题/金额/副标题），Web 比 [sp] 再小一档。
  static double cardSp(num value) => isWeb
      ? value.toDouble() * webWidthScale * webCardTextScale
      : value.sp;
}
