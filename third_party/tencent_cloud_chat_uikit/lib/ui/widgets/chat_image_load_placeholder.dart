import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 聊天图片加载失败 / 缺 URL 占位（气泡、全屏预览共用）。
class ChatImageLoadPlaceholder extends StatelessWidget {
  const ChatImageLoadPlaceholder({
    super.key,
    this.width = 170,
    this.height = 170,
    this.borderRadius,
    this.backgroundColor,
    this.iconColor,
    this.iconSize = 40,
    this.useSvgIcon = true,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final double iconSize;
  final bool useSvgIcon;

  static const String _imageSvgAsset =
      'packages/tencent_cloud_chat_uikit/images/svg/send_image.svg';

  /// 聊天气泡内占位（固定约 170×170，与历史 errorDisplay 一致）。
  factory ChatImageLoadPlaceholder.bubble({
    Key? key,
    TUITheme? theme,
    double width = 170,
    double height = 170,
    BorderRadius? borderRadius,
  }) {
    return ChatImageLoadPlaceholder(
      key: key,
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(6),
      backgroundColor: theme?.weakDividerColor ?? const Color(0xFFE8E8E8),
      iconColor: theme?.weakTextColor ?? const Color(0xFFBDBDBD),
      iconSize: 36,
    );
  }

  /// 全屏/弹层预览失败占位。
  factory ChatImageLoadPlaceholder.preview({
    Key? key,
    double? width,
    double? height,
  }) {
    return ChatImageLoadPlaceholder(
      key: key,
      width: width ?? 240,
      height: height ?? 180,
      borderRadius: BorderRadius.circular(8),
      backgroundColor: const Color(0xFF2C2C2C),
      iconColor: Colors.white38,
      iconSize: 48,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(6);
    final bg = backgroundColor ?? const Color(0xFFE8E8E8);
    final fg = iconColor ?? const Color(0xFFBDBDBD);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1),
      ),
      alignment: Alignment.center,
      child: _buildIcon(fg),
    );
  }

  Widget _buildIcon(Color color) {
    if (useSvgIcon) {
      return SvgPicture.asset(
        _imageSvgAsset,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(Icons.image_outlined, size: iconSize, color: color);
  }
}
